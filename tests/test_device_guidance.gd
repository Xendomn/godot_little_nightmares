extends SceneTree

const CONTENT = preload("res://scripts/puzzles/campaign_content.gd")
const DEVICE = preload("res://scripts/puzzles/device.gd")
var failures: Array[String] = []

class TestRoom extends Node3D:
	var theme := "workshop"
	var index := 0
	var objects: Dictionary = {}
	func all_met(needs: Array) -> bool:
		for need in needs:
			if not met(str(need)): return false
		return true
	func met(expression: String) -> bool:
		if expression.contains("&"):
			for part in expression.split("&"):
				if not met(part): return false
			return true
		var parts := expression.split(":")
		if not objects.has(parts[0]): return false
		return objects[parts[0]].state == int(parts[1]) if parts.size() > 1 else objects[parts[0]].satisfied()

class Hands extends Node:
	var carried: Node3D

class Part extends Node3D:
	var item_kind := "fuse"
	var socket_id := ""

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var probe = DEVICE.new()
	check(probe.has_method("display_name") and probe.has_method("state_label") and probe.has_method("get_blocked_reason"), "Devices expose readable names, states and blocked reasons")
	probe.free()
	if not failures.is_empty():
		quit(1)
		return
	var actor := Node3D.new()
	var hands := Hands.new()
	hands.name = "Interactions"
	actor.add_child(hands)
	root.add_child(actor)
	for theme in CONTENT.IDS:
		var rooms: Array = CONTENT.rooms(theme)
		for index in rooms.size():
			var room := TestRoom.new()
			room.theme = theme
			room.index = index
			root.add_child(room)
			for spec in rooms[index].devices:
				var device = DEVICE.new()
				device.spec = spec.duplicate(true)
				device.object_id = spec.id
				device.room = room
				room.objects[spec.id] = device
				room.add_child(device)
			for device in room.objects.values():
				check(device.display_name() != device.object_id and not device.display_name().is_empty(), "Named device: " + theme + "/" + device.object_id)
				check(device.get_prompt().contains(device.display_name()), "Prompt identifies device")
				if device.spec.kind == "selector":
					for value in int(device.spec.modes):
						check(not device.state_label(value).is_empty() and device.state_label(value) != str(value), "Meaningful selector state")
				if device.spec.kind == "plate":
					check(device.get_blocked_reason(actor).contains("箱子") and not device.can_interact(actor), "Plate explains physical crate requirement")
				if device.spec.kind == "brake":
					device.timer = 4.2
					check(device.get_prompt().contains("4.2"), "Brake displays actual remaining timer")
					device.timer = 0
					device.state = 1
					check(device.get_prompt().contains("12") and device.get_prompt().contains("重新"), "Expired brake offers reactivation")
			if theme == "workshop" and index == 0:
				var socket = room.objects.fuse_socket
				check(socket.get_blocked_reason(actor).contains("保险丝"), "Empty socket identifies missing part")
				check(room.objects.hatch.get_blocked_reason(actor).contains(socket.display_name()), "Locked latch names prerequisite")
				var part := Part.new()
				room.add_child(part)
				hands.carried = part
				check(socket.get_blocked_reason(actor).contains("本房间"), "Foreign part identifies room restriction")
				room.objects.part = part
				part.item_kind = "gear"
				check(socket.get_blocked_reason(actor).contains("保险丝"), "Wrong part identifies accepted part")
				part.item_kind = "fuse"
				check(socket.get_blocked_reason(actor).is_empty() and socket.can_interact(actor), "Correct part remains usable")
				socket.occupied = part
				part.socket_id = socket.object_id
				check(not socket.get_blocked_reason(actor).is_empty(), "Occupied hands explain filled socket rejection")
				hands.carried = null
				check(socket.get_blocked_reason(actor).is_empty(), "Filled socket permits retrieval with empty hands")
				socket.restore_state(socket.capture_state())
				check(not socket.satisfied(), "Device restore clears occupancy for room snapshot relinking")
				socket.occupied = part
				check(socket.satisfied() and socket.get_blocked_reason(actor).is_empty(), "Relinked snapshot restores retrievable socket")
				part.socket_id = ""
				hands.carried = part
				check(not socket.satisfied() and socket.can_interact(actor) and socket.get_blocked_reason(actor).is_empty(), "Removed part can be reinserted despite stale occupancy reference")
				hands.carried = null
				room.objects.erase("part")
			if theme == "workshop" and index == 1:
				var cargo = room.objects.cargo
				cargo.spec.needs = ["upper_latch&route:2"]
				var reason: String = cargo.get_blocked_reason(actor)
				check(reason.contains(room.objects.route.display_name()) and reason.contains(room.objects.route.state_label(2)) and reason.contains(room.objects.upper_latch.display_name()), "Compound dependencies name controls and required selector meaning")
				room.objects.route.spec.display_name = "自定义旋钮"
				room.objects.route.spec.state_names = ["关闭", "升起", "送货"]
				check(room.objects.route.display_name() == "自定义旋钮" and room.objects.route.state_label(2) == "送货", "Editor overrides take precedence")
			room.free()
	actor.free()
	print("Device guidance checks: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

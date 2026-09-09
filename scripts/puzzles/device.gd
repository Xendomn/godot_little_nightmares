extends Node3D
## A physical control; dependency expressions are evaluated by the owning room.
const LABELS = preload("res://scripts/puzzles/device_labels.gd")
var object_id := ""
var spec: Dictionary
var room: Node3D
var state := 0
var timer := 0.0
var occupied: Node3D
var lamp: OmniLight3D

func _ready() -> void:
	add_to_group("puzzle_interactable")
	state = int(spec.get("initial", 0))
	lamp = OmniLight3D.new()
	lamp.position = Vector3(0,.4,.15)
	lamp.omni_range = 2.2
	lamp.light_energy = .6
	add_child(lamp)

func satisfied() -> bool:
	if spec.kind == "socket":
		return is_instance_valid(occupied) and occupied.socket_id == object_id
	if spec.kind == "plate":
		var total := 0.0
		for thing in room.objects.values():
			if thing is CharacterBody3D and "mass" in thing and not thing.get("held"):
				if absf(thing.global_position.x-global_position.x) < .85 and absf(thing.global_position.z-global_position.z) < 1.15 and absf(thing.global_position.y-room.global_position.y) < .6:
					total += thing.mass
		return total >= float(spec.get("mass",1.0))
	if spec.kind in ["brake", "bell"]:
		return timer > 0
	return state > 0

func can_interact(actor: Node3D) -> bool:
	if spec.kind == "plate":
		return false
	if spec.kind == "socket":
		var carried = actor.get_node("Interactions").carried
		return room.all_met(spec.get("needs",[])) and ((carried != null and carried.item_kind == spec.accept and carried in room.objects.values() and not satisfied()) or satisfied() and carried == null)
	return room.all_met(spec.get("needs",[]))

func interact(actor: Node3D) -> void:
	if not can_interact(actor):
		return
	match spec.kind:
		"socket":
			var controller = actor.get_node("Interactions")
			if satisfied():
				if controller.release_socket(occupied): occupied = null
			else:
				occupied = controller.attach_carried(self)
		"selector":
			state = (state + 1) % int(spec.get("modes",3))
			if spec.has("linked_to"):
				room.objects[str(spec.linked_to)].state = state
		"brake":
			state = 1
			timer = 12.0
		"bell":
			state = 1
			timer = 12.0
		"travel": state = 1-state
		_: state = 1
	if room.machines: room.machines.control_used(self)
	room.feedback("bell" if object_id == "bell" else ("fuse_insert" if spec.kind == "socket" else "metal_latch"))
	actor.visual_driver.play("interact", .35)

func get_prompt() -> String:
	var action := "操作"
	match spec.kind:
		"selector": action = "切换 · 当前：" + state_label(state)
		"socket": action = ("取回" if satisfied() else "安装") + str(LABELS.PARTS.get(spec.get("accept", ""), "部件"))
		"brake": action = "剩余 %.1f 秒 · 重新制动 12 秒" % timer if timer > 0 else "重新制动 12 秒"
		"latch": action = "已开启" if satisfied() else "开启"
		"plate": action = "重物已到位" if satisfied() else "需要箱子压住踏板"
		"bell": action = "再次敲响 · 回声 %.1f 秒" % timer if timer > 0 else "敲响"
		"travel": action = "呼叫停靠" if object_id != "lift_trip" else "切换上下行程"
	return "{interact} · " + display_name() + " · " + action

func display_name() -> String:
	return str(LABELS.describe(room.theme, room.index, object_id, spec).display_name)

func state_label(value: int) -> String:
	var names: Array = LABELS.describe(room.theme, room.index, object_id, spec).state_names
	return str(names[value]) if value >= 0 and value < names.size() else "档位 %d" % value

func get_blocked_reason(actor: Node3D) -> String:
	if spec.kind == "plate":
		return "需要箱子压住" + display_name() if not satisfied() else "重物已到位"
	var reasons: Array[String] = []
	for expression in spec.get("needs", []):
		_append_unmet(str(expression), reasons)
	if not reasons.is_empty():
		return "需要先完成：" + "；".join(reasons)
	if spec.kind != "socket":
		return ""
	var carried = actor.get_node("Interactions").carried
	var part_name: String = LABELS.PARTS.get(spec.get("accept", ""), "部件")
	if satisfied():
		return "插座已装满；请退开后按{interact}放下手中物品，再取回" + part_name if carried != null else ""
	if carried == null:
		return "需要携带" + part_name + "，再安装到" + display_name()
	if carried.item_kind != spec.accept:
		return display_name() + "需要" + part_name + "；手中部件不匹配"
	if carried not in room.objects.values():
		return "需要本房间的" + part_name
	return ""

func _append_unmet(expression: String, reasons: Array[String]) -> void:
	if expression.contains("&"):
		for part in expression.split("&"):
			_append_unmet(part, reasons)
		return
	var parts := expression.split(":")
	var device = room.objects.get(parts[0])
	if device == null:
		if not room.met(expression):
			var names := {"cargo_caught":"货箱尚未抵达挡扣", "press_supported":"压头尚未落稳", "water_low":"水位仍高于安全刻度", "raft_high":"浮箱尚未抵达高台", "left_high":"左侧水位尚未到达刻度", "right_high":"右侧水位尚未到达刻度", "water_high":"蓄水尚未到达刻度", "hydraulic_ready":"活塞尚未推出", "weight_high":"货篮尚未对准停靠线", "exchange_left":"左平台尚未停稳", "exchange_right":"右平台尚未停稳", "bridge_supported":"桥面尚未抬起", "cargo_at_top":"货台尚未停稳", "shafts_aligned":"两根指针尚未重合", "clock_aligned":"指针尚未进入标记区", "rack_open":"齿条尚未退出", "span_a_ready":"第一段桥尚未抬起", "span_b_ready":"第二段桥尚未抬起", "span_c_ready":"第三段桥尚未抬起"}
			var reason: String = names.get(expression,"机关尚未到位")
			if not reasons.has(reason): reasons.append(reason)
		return
	var reason := ""
	if parts.size() > 1:
		var required := int(parts[1])
		if device.state != required:
			reason = device.display_name() + " → " + device.state_label(required)
	elif not device.satisfied():
		reason = device.display_name()
		if device.spec.kind == "brake": reason += "（重新制动 12 秒）"
		elif device.spec.kind == "plate": reason += "（用箱子压住）"
		elif device.spec.kind == "socket": reason += "（安装" + str(LABELS.PARTS.get(device.spec.get("accept", ""), "部件")) + "）"
	if not reason.is_empty() and not reasons.has(reason): reasons.append(reason)

func update(delta: float) -> void:
	if spec.has("linked_to"): state = room.objects[str(spec.linked_to)].state
	timer = maxf(0,timer-delta)
	lamp.light_color = Color(.3, .95, .85) if satisfied() else Color(.95,.42,.12)
	var pivot = find_child("Lever", true, false)
	if pivot:
		pivot.rotation.z = lerp_angle(pivot.rotation.z, -.5 + state * .5, minf(1,delta*8))

func capture_state() -> Dictionary:
	return {"state":state,"timer":timer}
func restore_state(data: Dictionary) -> void:
	state = int(data.get("state",spec.get("initial",0)))
	timer = float(data.get("timer",0))
	occupied = null

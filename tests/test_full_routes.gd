extends SceneTree
## Walkthrough smoke test: all progress comes from Input actions and physics.
## No player teleport, direct interact(), state mutation, or completion shortcuts.
const TestInput = preload("res://tests/input_events.gd")
const CONTENT = preload("res://scripts/puzzles/campaign_content.gd")
const ROUTES := {
	"workshop": [
		["push:10", "pull:3", "push:10", "pull:3", "item:fuse", "fuse_socket", "hatch"],
		["route", "up", "upper_latch", "down", "route", "cargo"],
		["belt", "wait:cargo_plate", "delivery"],
		["power", "push:23", "power", "service"],
		["item:fuse_a", "socket_a", "up", "item:fuse_b", "lift_down", "socket_b", "junction"],
		["belt", "belt", "barrier", "chute"]
	],
	"laundry": [
		["inlet", "drain", "outlet"],
		["push:18", "fill", "up", "high_valve", "down"],
		["transfer", "up", "left_valve", "down", "transfer", "transfer", "right_valve"],
		["basket", "up", "item:wheel", "lift_down", "valve_socket", "return"],
		["item:wheel", "bypass", "pressure", "up", "vent", "down", "pressure", "seal"],
		["item:gear", "wheel_drive", "timing", "timing", "steam_lock"]
	],
	"thread_vault": [
		["item:weight_a", "tray_a", "item:weight_b", "tray_b", "up", "landing", "down"],
		["item:weight", "lower", "up", "stop", "down", "lower", "upper"],
		["item:weight", "tray", "up", "pin", "down", "tray", "reuse"],
		["hoist", "item:weight", "up", "receiver", "down", "shaft_gate"],
		["bell", "hoist", "up", "quiet_gate", "down"],
		["item:weight", "winch_a", "pin_a", "winch_a", "winch_b", "pin_b", "far_latch"]
	],
	"clocktower": [
		["item:gear", "gear_socket", "direction", "direction", "gear_door"],
		["clutch", "up", "shortcut", "down", "clutch", "pendulum_gate"],
		["brake_a", "brake_b", "phase_gate"],
		["item:gear_a", "lift_power", "up", "item:gear_b", "lift_down", "slow_axis", "fast_axis"],
		["item:weight", "counterweight", "phase", "phase", "phase", "clock_brake", "hammer"],
		["release", "brake_a", "brake_b", "sunrise"]
	]
}
var chapter: Node3D
var actor: CharacterBody3D
var failures: Array[String] = []
var room_index := 0
var chapter_id := ""
var completed := 0
func _initialize() -> void:
	call_deferred("run")
func release_inputs() -> void:
	for action in ["left", "right", "depth_up", "depth_down", "interact", "jump", "run"]:
		TestInput.release(action)
func frame(count: int = 1) -> void:
	for _i in count:
		await physics_frame
func fail(message: String) -> bool:
	var context := "%s room %d: %s at %s" % [chapter_id, room_index + 1, message, str(actor.global_position) if actor else "no player"]
	failures.append(context)
	push_error(context)
	release_inputs()
	return false
func walk_to(destination: Vector3, tolerance: float = .18, max_frames: int = 1800) -> bool:
	release_inputs()
	var room := current_room() if chapter != null else null
	if room != null and room.lift != null and actor.global_position.y < .3 and room.met(str(room.spec.lift)):
		var left: float = room.global_position.x + 18.9
		var right: float = room.global_position.x + 23.1
		if (actor.global_position.x > right and destination.x < left) or (actor.global_position.x < left and destination.x > right):
			for _wait in 900:
				if room.lift.position.y > 3.05 and fmod(room.phase, 12) < 8:
					break
				await frame()
	if room != null and room.spec.has("hazards") and actor.global_position.y < .3:
		for h in 2:
			var hx: float = room.global_position.x + (21 if h == 0 else 32)
			if actor.global_position.x < hx - .7 and destination.x > hx + .7:
				if not await walk_to(Vector3(hx - .95, actor.global_position.y, destination.z)):
					return false
				for _wait in 360:
					var cycle: float = fmod(room.phase + h * 1.4, 4)
					if room.met("brake_a" if h == 0 else "brake_b") or (cycle >= 2.1 and cycle < 2.4):
						break
					await frame()
				# Start close enough that this short crossing does not recurse.
				TestInput.press("right")
				for _cross in 70:
					await frame()
					if not actor.enabled:
						return fail("Hazard crossing failed")
					if actor.global_position.x > hx + .8:
						break
				release_inputs()
	var stalled := 0
	var last := actor.global_position
	for i in max_frames:
		var difference := destination - actor.global_position
		if Vector2(difference.x, difference.z).length() <= tolerance:
			release_inputs()
			await frame(3)
			return true
		TestInput.release("left")
		TestInput.release("right")
		TestInput.release("depth_up")
		TestInput.release("depth_down")
		if absf(difference.x) > tolerance * .6:
			TestInput.press("right" if difference.x > 0 else "left")
		if absf(difference.z) > tolerance * .6:
			TestInput.press("depth_down" if difference.z > 0 else "depth_up")
		await frame()
		if not actor.enabled and room_index == 5 and actor.global_position.x >= 273:
			release_inputs()
			return true
		if not actor.enabled:
			return fail("Player disabled while walking to " + str(destination))
		if actor.global_position.distance_to(last) < .001:
			stalled += 1
		else:
			stalled = 0
		last = actor.global_position
		if stalled > 120:
			return fail("Physical obstruction walking to " + str(destination))
	return fail("Walk timeout to " + str(destination))
func press_interact() -> void:
	TestInput.release("interact")
	await frame(2)
	TestInput.press("interact")
	await frame(2)
	TestInput.release("interact")
	await frame(4)
func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result
func find_object(local_id: String) -> Node3D:
	for node in descendants(chapter):
		if node is Node3D and "object_id" in node:
			var id := str(node.object_id)
			if id == local_id or id.ends_with("/" + local_id) or id.ends_with("_" + local_id):
				# Scope persistent IDs by physical room rather than a global query.
				if absf(node.global_position.x - (room_index * 46 + 23)) < 25:
					return node
	return null
func use_object(local_id: String, picking: bool = false) -> bool:
	var target := find_object(local_id)
	if target == null:
		return fail("Missing target " + local_id)
	var side := -1.0 if actor.global_position.x < target.global_position.x else 1.0
	var approach := target.global_position + (Vector3(side * .65, 0, .15) if picking else Vector3(0, 0, .15))
	approach.y = actor.global_position.y
	if absf(approach.x - actor.global_position.x) > 2:
		if not await walk_to(Vector3(actor.global_position.x, actor.global_position.y, 1.3)):
			return false
		if not await walk_to(Vector3(approach.x, actor.global_position.y, 1.3)):
			return false
	if not await walk_to(approach):
		return false
	await frame(3)
	var controller = actor.get_node("Interactions")
	if controller.current_target != target:
		return fail("Wrong selected target for %s: %s" % [local_id, str(controller.current_target)])
	await press_interact()
	if picking and controller.carried != target:
		return fail("Pickup did not take " + local_id)
	return true
func push_crate(destination_x: float, pulling: bool = false) -> bool:
	var crate: Node3D
	for node in descendants(chapter):
		if node is CharacterBody3D and node.has_method("move_with_actor") and absf(node.global_position.x - (room_index * 46 + 23)) < 25:
			crate = node
			break
	if crate == null:
		return fail("Missing crate")
	var target_x := room_index * 46 + destination_x
	var direction := 1.0 if target_x > crate.global_position.x else -1.0
	if not await walk_to(crate.global_position + Vector3((direction if pulling else -direction) * .85, 0, 0)):
		return false
	TestInput.press("interact")
	await frame(3)
	if actor.get_node("Interactions").pushed != crate:
		return fail("Crate did not enter push mode")
	TestInput.press("right" if direction > 0 else "left")
	var previous: float = crate.global_position.x
	var stalled := 0
	for _i in 1800:
		await frame()
		if absf(crate.global_position.x - target_x) < .2:
			release_inputs()
			await frame(5)
			return true
		if absf(crate.global_position.x - previous) < .001:
			stalled += 1
		else:
			stalled = 0
		previous = crate.global_position.x
		if stalled > 120:
			return fail("Crate obstruction toward " + str(target_x))
	return fail("Crate push timeout")
func current_room() -> Node3D:
	for node in descendants(chapter):
		if "objects" in node and "index" in node and node.index == room_index:
			return node
	return null
func ride_lift(upward: bool) -> bool:
	var room := current_room()
	if room == null or room.lift == null:
		return fail("Missing lift")
	var wait_x: float = room.global_position.x + (18.0 if upward else 24.0)
	if not await walk_to(Vector3(wait_x, actor.global_position.y, 1.3)):
		return false
	var boarded := false
	for _i in 1200:
		await frame()
		var lift_y: float = room.lift.position.y
		if (upward and lift_y < .08) or (not upward and lift_y > 3.05):
			if not await walk_to(Vector3(room.global_position.x + 21, actor.global_position.y, 0)):
				return false
			boarded = true
			break
	if not boarded:
		return fail("Lift never arrived")
	for _i in 1200:
		await frame()
		if (upward and actor.global_position.y > 3.1) or (not upward and actor.global_position.y < .2):
			return await walk_to(Vector3(room.global_position.x + (24 if upward else 18), actor.global_position.y, 0))
	return fail("Lift did not carry player")
func descend_ladder() -> bool:
	var room := current_room()
	if room == null or room.ladder == null:
		return fail("Missing return ladder")
	if not await walk_to(room.ladder.global_position + Vector3(-.35, actor.global_position.y, 0)):
		return false
	await press_interact()
	if actor.get_node("Interactions").ladder != room.ladder:
		return fail("Ladder failed to attach")
	TestInput.press("depth_down")
	for _i in 240:
		await frame()
		if actor.global_position.y < .1:
			release_inputs()
			await press_interact()
			return true
	return fail("Ladder descent blocked")
func run() -> void:
	var only := OS.get_environment("ROUTE_CHAPTER")
	for id in CONTENT.IDS:
		if not only.is_empty() and only != id:
			continue
		chapter_id = id
		var path := "res://scenes/chapters/full/%s.tscn" % id
		if not ResourceLoader.exists(path):
			fail("Chapter scene not generated: " + path)
			continue
		chapter = load(path).instantiate()
		chapter.managed = true
		root.add_child(chapter)
		await frame(5)
		chapter.start_game()
		actor = chapter.player
		await frame(5)
		var blocked := false
		for index in 6:
			room_index = index
			print("ROUTE %s room %d" % [id, index+1])
			for action in ROUTES[id][index]:
				var ok: bool
				if action == "up":
					ok = await ride_lift(true)
				elif action == "lift_down":
					ok = await ride_lift(false)
				elif action == "down":
					ok = await descend_ladder()
				elif action.begins_with("wait:"):
					ok = await wait_for_condition(action.get_slice(":",1))
				elif action.begins_with("pull:"):
					ok = await push_crate(float(action.get_slice(":",1)), true)
				elif action.begins_with("push:"):
					ok = await push_crate(float(action.get_slice(":",1)))
				else:
					ok = await use_object(action.get_slice(":",1) if action.begins_with("item:") else action, action.begins_with("item:"))
				if not ok:
					blocked = true
					break
			if blocked:
				break
			await frame(10)
			if not current_room().completed:
				fail("Route actions did not complete puzzle")
				break
			completed += 1
			print("PASS: physical route %s room %d" % [id,index+1])
			if not await walk_to(Vector3(index*46+45,actor.global_position.y,0)):
				break
		print("KNOWN-SOLUTION SECONDS ",id,": ",chapter.play_time)
		chapter.queue_free()
		chapter = null
		actor = null
		await frame(4)
	# Audio playback retirement runs on its own thread, even at accelerated fixed FPS.
	OS.delay_msec(150)
	await frame(4)
	print("PHYSICAL ROUTES PASSED: %d / %d" % [completed,24 if only.is_empty() else 6])
	quit(1 if not failures.is_empty() else 0)

func wait_for_condition(expression: String) -> bool:
	for _i in 1800:
		await frame()
		if current_room().met(expression):
			return true
	return fail("Machine condition timed out: " + expression)

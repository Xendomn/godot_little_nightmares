extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for file in ["interaction_controller", "carry_item", "pushable", "ladder"]:
		check(ResourceLoader.exists("res://scripts/puzzles/%s.gd" % file), "Missing interaction behavior: " + file)
	if not failures.is_empty():
		quit(1)
		return
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(40, .2, 10)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position = Vector3(0, -.1, 0)
	world.add_child(floor_body)
	var player = load("res://scenes/actors/player.tscn").instantiate()
	player.extended_interactions = true
	var original_visual = player.get_node("Visual")
	player.remove_child(original_visual)
	original_visual.free()
	var expanded_visual = load("res://assets/models/expansion/doll_interactions.glb").instantiate()
	expanded_visual.name = "Visual"
	player.add_child(expanded_visual)
	world.add_child(player)
	player.position = Vector3.ZERO
	player.set_physics_process(false)
	player.enabled = true
	var control = player.get_node("Interactions")
	var item = load("res://scripts/puzzles/carry_item.gd").new()
	item.position = Vector3(0.8, 0.3, 0)
	world.add_child(item)
	await physics_frame
	control.refresh_target()
	check(control.current_target == item, "Nearby item selected")
	var nearby_ladder = load("res://scripts/puzzles/ladder.gd").new()
	nearby_ladder.position.x = .7
	world.add_child(nearby_ladder)
	item.position = Vector3(.1, .8, 0)
	item.set_physics_process(false)
	await physics_frame
	await physics_frame
	control.refresh_target()
	check(control.current_target == item, "Target scoring uses player hands, not feet")
	nearby_ladder.free()
	item.position = Vector3(.8, .3, 0)
	item.set_physics_process(true)
	check(control.pickup(item), "Nearby item picked up")
	check(control.carried == item and item.collision_layer == 0, "Carried item stops colliding")
	player.animate_doll(.016, 0)
	check(player.visual_driver.current == "carry_idle", "Carrying at rest selects carry idle pose")
	player.velocity.x = 1.0
	player.animate_doll(.016, 1)
	check(player.visual_driver.current == "carry_walk", "Carrying in motion selects carry walk pose")
	player.velocity = Vector3.ZERO
	for clip in ["carry_idle", "carry_walk", "pull", "climb"]:
		check(player.visual_driver.clips.has(clip), "Expanded rig contains " + clip)
		if player.visual_driver.clips.has(clip):
			check(player.visual_driver.animator.get_animation(player.visual_driver.clips[clip]).loop_mode == Animation.LOOP_LINEAR, "Interaction pose loops: " + clip)
	var socket := Node3D.new()
	world.add_child(socket)
	socket.position = Vector3(1, 1, 0)
	check(control.attach_carried(socket) == item, "Socket attaches carried item")
	check(control.carried == null and item.global_position == socket.global_position, "Socket clears hands and places item")
	check(control.release_socket(item), "Socket item reusable")
	control.cancel_interaction()
	check(control.carried == null and item.collision_layer != 0, "Cancellation drops item with collision")
	item.global_position = Vector3(8, 0, 0)
	control.refresh_target()
	check(control.current_target == null and not control.pickup(item), "Remote pickup rejected")
	item.global_position = Vector3(1, .3, 0)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.2, 3, 3)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(.5, 1, 0)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	control.refresh_target()
	check(control.current_target == null, "Wall blocks selection")
	check(not control.pickup(item), "Wall blocks direct pickup")
	wall.queue_free()
	await physics_frame
	await physics_frame
	check(control.pickup(item), "Pickup after removing wall")
	var blocker := StaticBody3D.new()
	var block_shape := CollisionShape3D.new()
	var block_box := BoxShape3D.new()
	block_box.size = Vector3(1, 3, 3)
	block_shape.shape = block_box
	blocker.add_child(block_shape)
	blocker.position = Vector3(.95, 1, 0)
	world.add_child(blocker)
	await physics_frame
	await physics_frame
	check(not control.place_carried() and control.carried == item, "Blocked placement retains carried item")
	control.cancel_interaction()
	var pushable = load("res://scripts/puzzles/pushable.gd").new()
	world.add_child(pushable)
	pushable.position = Vector3(4, 1, 0)
	pushable.object_id = "crate"
	var state: Dictionary = JSON.parse_string(JSON.stringify(pushable.capture_state()))
	pushable.position.x = 10
	pushable.restore_state(state)
	check(is_equal_approx(pushable.position.x, 4), "Object state survives JSON round trip")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	var ladder = load("res://scripts/puzzles/ladder.gd").new()
	world.add_child(ladder)
	ladder.height = 3
	player.position = Vector3.ZERO
	check(control.attach_ladder(ladder), "Ladder attaches nearby player")
	player.animate_doll(.016, 1)
	check(player.visual_driver.current == "climb", "Attached ladder selects climb pose")
	control.cancel_interaction()
	check(control.ladder == null and not player.pushing, "Cancel exits ladder and push state")
	ladder.queue_free()
	item.queue_free()
	pushable.position = Vector3(.85, 0, 0)
	pushable.set_physics_process(false)
	player.position = Vector3.ZERO
	await physics_frame
	await physics_frame
	check(control.begin_push(pushable), "Reachable crate enters push mode")
	Input.action_press("left")
	player.animate_doll(.016, 1)
	check(player.visual_driver.current == "pull", "Away input while holding crate selects pull pose")
	Input.action_release("left")
	pushable.move_with_actor(player, -1, .2)
	check(player.position.x < -.2 and pushable.position.x < .65, "Pull moves both actor and crate")
	pushable.move_with_actor(player, 1, .2)
	check(absf(player.position.x) < .02 and absf(pushable.position.x - .85) < .02, "Push reverses pull")
	player.enabled = false
	check(control.pushed == null and pushable.handler == null, "Disable releases crate")
	var rear_wall := StaticBody3D.new()
	var rear_collision := CollisionShape3D.new()
	var rear_box := BoxShape3D.new()
	rear_box.size = Vector3(.2, 3, 3)
	rear_collision.shape = rear_box
	rear_wall.add_child(rear_collision)
	rear_wall.position = Vector3(-.45, 1, 0)
	world.add_child(rear_wall)
	await physics_frame
	await physics_frame
	var old_x: float = pushable.position.x
	pushable.move_with_actor(player, -1, .2)
	check(is_equal_approx(pushable.position.x, old_x), "Pull cannot crush player into rear wall")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS puzzle interactions")
	quit(0 if failures.is_empty() else 1)

extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1
func input_frames(control: Node, action: String, count: int) -> void:
	Input.action_press(action)
	for i in range(count):
		control.tick(1.0/60)
		await physics_frame
	Input.action_release(action)
func run() -> void:
	var game = load("res://scenes/chapters/full/workshop.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	game.start_game()
	game.set_process(false)
	var actor = game.player
	actor.set_physics_process(false)
	var control = actor.get_node("Interactions")
	var room = game.rooms[1]
	for bay in game.rooms: bay.set_physics_process(false)
	var space = actor.get_world_3d().direct_space_state
	var offset: Vector3 = room.global_position
	var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(offset + Vector3(7,1,2.2),offset + Vector3(9,1,2.2),1))
	check(not hit.is_empty(), "side arch pier has collision")
	actor.global_position = offset + Vector3(6,0.03,0)
	check(not actor.test_move(actor.global_transform, Vector3(4,0,0)), "central route remains open beneath arch")
	actor.global_position = offset+Vector3(8,.03,0)
	await frames(18)
	var visible_player := false
	for mesh in room.find_children("*","MeshInstance3D",true,false):
		if mesh.global_position.z > 1.5 and mesh.transparency > .5: visible_player = true
	check(visible_player,"foreground pier fades near actor without disabling collision")
	actor.global_position = offset + Vector3(6,.03,2.2)
	check(actor.test_move(actor.global_transform,Vector3(4,0,0)), "actor shape cannot pass through side pier")
	var crate = load("res://scripts/puzzles/pushable.gd").new()
	game.add_child(crate)
	crate.set_physics_process(false)
	crate.global_position = offset + Vector3(6.8,.03,2.2)
	await frames(2)
	check(crate.test_move(crate.global_transform,Vector3(4,0,0)), "crate shape cannot pass through side pier")
	for i in range(12): crate.move_with_actor(actor,1,.1)
	check(crate.global_position.x < offset.x+7.4 and actor.global_position.x < crate.global_position.x, "pushing into pier stops actor and crate together")
	crate.free()
	check(not room.ladder.get_prompt().contains("Climb"), "ladder interaction is Chinese")
	var carry = load("res://scripts/puzzles/carry_item.gd").new()
	carry.item_kind = "weight"
	check(carry.get_prompt().contains("砝码"), "item prompt uses Chinese display name")
	carry.free()
	if failures:
		game.queue_free()
		await frames(2)
		quit(1)
		return
	room.ladder.visible = true
	actor.global_position = room.ladder.global_position + Vector3(0,.03,0)
	check(control.attach_ladder(room.ladder), "attach at ladder foot")
	check(is_equal_approx(actor.model.rotation.y,room.ladder.facing_y), "climb faces the ladder")
	await input_frames(control,"depth_up",45)
	var animation_time: float = actor.visual_driver.playback.get_current_play_position()
	for i in range(20):
		control.tick(1.0/60)
		await physics_frame
	check(is_equal_approx(animation_time,actor.visual_driver.playback.get_current_play_position()), "stationary grip does not cycle climbing animation")
	check(control.ladder_grip.contacts.size() == 2, "both hand contacts evaluated after animation")
	for i in range(control.ladder_grip.contacts.size()):
		check(control.ladder_grip.contacts[i].distance_to(control.ladder_grip.targets[i]) < .06,"hand reaches an actual rung")
	paused = true
	await frames(5)
	check(is_equal_approx(animation_time,actor.visual_driver.playback.get_current_play_position()), "pause freezes ladder pose")
	paused = false
	Input.action_press("depth_up")
	for i in range(160):
		control.tick(1.0/60)
		await physics_frame
		if control.ladder == null: break
	Input.action_release("depth_up")
	check(control.ladder == null and actor.global_position.x < room.global_position.x + 35 and actor.global_position.y >= room.global_position.y + 3.19, "climb automatically lands on upper walkway")
	check(not actor.visual_driver.climbing and not control.ladder_grip.active, "landing restores normal animation and releases hands")
	check(control.attach_ladder(room.ladder), "ladder accessible from upper landing")
	await input_frames(control,"depth_down",130)
	check(control.ladder == null and actor.global_position.y < .05, "descent automatically releases at floor")
	# A blocked landing must keep the player attached and allow retreat.
	actor.global_position = room.ladder.global_position+Vector3(0,3.23,0)
	var obstruction = room.solid("LandingTestBlock",Vector3(34.6,3.8,0),Vector3(.7,1,1),Color.WHITE)
	await frames(2)
	check(control.attach_ladder(room.ladder), "attach beside blocked landing")
	await input_frames(control,"depth_up",10)
	check(control.ladder != null and is_equal_approx(actor.global_position.x,room.ladder.global_position.x), "blocked top cannot teleport into platform obstacle")
	await input_frames(control,"depth_down",12)
	check(control.ladder != null and actor.global_position.y < 3.1, "blocked top permits climbing back down")
	obstruction.free()
	control.detach_ladder()
	actor.global_position = room.ladder.global_position+Vector3(0,3.23,0)
	control.attach_ladder(room.ladder)
	await input_frames(control,"depth_up",5)
	check(actor.global_position.x < room.ladder.global_position.x,"top transfer begins with collision-aware movement")
	var moving_block = room.solid("ArrivingBlock",Vector3(34.7,3.8,0),Vector3(.7,1,1),Color.WHITE)
	await frames(2)
	await input_frames(control,"depth_down",20)
	check(control.ladder != null and actor.global_position.y < 3.1 and absf(actor.global_position.x-room.ladder.global_position.x) < .02,"obstructed transfer can retreat to ladder and descend")
	moving_block.free()
	Input.action_press("jump")
	await physics_frame
	control.tick(1.0/60)
	Input.action_release("jump")
	check(control.ladder == null and not actor.visual_driver.climbing, "jump input lets go and resets animation")
	# Exercise normal player locomotion, with stale grounded flags from before climbing.
	actor.global_position = room.ladder.global_position+Vector3(0,.03,0)
	actor.velocity = Vector3(0,-1,0)
	actor.move_and_slide()
	control.attach_ladder(room.ladder)
	await input_frames(control,"depth_up",45)
	Input.action_press("jump")
	await physics_frame
	actor._physics_process(1.0/60)
	Input.action_release("jump")
	check(control.ladder == null and actor.velocity.y <= 0,"letting go cannot reuse stale floor state to jump in midair")
	actor.global_position = room.ladder.global_position+Vector3(0,3.8,0)
	var above: Vector3 = actor.global_position
	check(not control.attach_ladder(room.ladder) and actor.global_position == above,"airborne attachment above top is rejected without snapping")
	actor.global_position = room.ladder.global_position+Vector3(0,.03,0)
	actor.crouching = true
	(actor.collider.shape as CapsuleShape3D).height = .64
	actor.collider.position.y = .34
	var low_roof = room.solid("LowRoofTest",Vector3(35.7,.95,0),Vector3(1,.2,1),Color.WHITE)
	await frames(2)
	check(not control.attach_ladder(room.ladder),"crouched player cannot attach and stand through low ceiling")
	low_roof.free()
	await frames(2)
	actor.global_position = room.ladder.global_position+Vector3(0,1.5,0)
	check(control.attach_ladder(room.ladder), "reattach halfway")
	actor.enabled = false
	check(control.ladder == null and not control.ladder_grip.active, "disable clears climbing and hand modifier")
	game.restore_checkpoint("room_1")
	check(control.ladder == null and not actor.visual_driver.climbing, "checkpoint cannot retain suspended animation")
	control.cancel_interaction()
	game.queue_free()
	await frames(3)
	var hints = root.get_node("InputHints")
	for id in ["workshop","laundry","thread_vault","clocktower"]:
		var chapter = load("res://scenes/chapters/full/"+id+".tscn").instantiate()
		root.add_child(chapter)
		await frames(3)
		var chinese := RegEx.new()
		chinese.compile("[一-鿿]")
		var localized := true
		var colliders := true
		for bay in chapter.rooms:
			colliders = colliders and bay.find_children("ArchCollision","StaticBody3D",true,false).size() == 6
			for object in bay.objects.values():
				if not object.has_method("get_prompt"): continue
				var prompt: String = object.get_prompt()
				localized = localized and chinese.search(prompt) != null
				for pad in [false,true]:
					hints.select_device(pad,0)
					localized = localized and not hints.format_text(prompt).contains("{")
		check(colliders,id+" all six bays have structural arch collisions")
		check(localized,id+" all object prompts are Chinese and resolve for keyboard/controller")
		chapter.queue_free()
		await frames(3)
	hints.select_device(false)
	check(hints.format_text("{vertical}").contains("↑/↓"), "keyboard ladder hint includes arrows")
	hints.select_device(true,0)
	check(hints.format_text("{vertical}").contains("上下") and hints.format_text("{pause}") == "菜单键", "controller ladder and menu hints are Chinese")
	hints.select_device(false)
	OS.delay_msec(200)
	await frames(2)
	print("ROOM REPAIR FAILURES: ",failures)
	quit(1 if failures else 0)

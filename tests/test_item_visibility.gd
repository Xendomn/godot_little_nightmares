extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func run() -> void:
	var game = load("res://scenes/chapters/full/workshop.tscn").instantiate()
	game.managed = true
	root.add_child(game)
	game.start_game()
	game.set_process(false)
	game.player.set_physics_process(false)
	for room in game.rooms: room.set_physics_process(false)
	var room = game.rooms[0]
	var fuse = room.objects.fuse
	var crate = room.objects.crate
	crate.set_physics_process(false)
	await frames(3)
	check(fuse.visible and fuse.collision_layer == 1, "initial fuse exists physically instead of scripted invisibility")
	check(fuse.position.z < -.7 and absf(fuse.position.x-crate.position.x) < .1, "fuse is physically behind crate outside push lane")
	for direction in [-1,1]:
		room.restore_state(room.initial)
		game.player.position = Vector3(6,.03,0)
		for i in 75:
			crate.move_with_actor(game.player,direction,1.0/60)
			await physics_frame
		room.update_fuse_presence()
		check(room.fuse_revealed and fuse.visible, "one move reveals fuse in direction %d" % direction)
		game.player.position = fuse.position + Vector3(-.5,.03,0)
		await frames(2)
		var control = game.player.get_node("Interactions")
		check(fuse.can_interact(game.player) and control.pickup(fuse), "revealed fuse can be picked up after either direction")
		control.carried = null
		fuse.set_held(false)
	room.restore_state(room.initial)
	var legacy: Dictionary = room.initial.duplicate(true)
	legacy.objects.fuse.position = [8.2,.08,1.05]
	legacy.fuse_revealed = false
	room.restore_state(legacy)
	check(fuse.visible and fuse.position.is_equal_approx(Vector3(7,.08,-.95)), "existing undiscovered save migrates to real object behind crate")
	legacy.fuse_revealed = true
	legacy.objects.fuse.position = [10,.08,1.2]
	room.restore_state(legacy)
	check(fuse.position.is_equal_approx(Vector3(10,.08,1.2)), "discovered loose save keeps dropped position")
	room.restore_state(room.initial)
	var visual = fuse.get_node_or_null("ItemPresentation")
	check(visual != null, "shared item presentation exists")
	if visual:
		check(visual.visual_bounds().size.y >= .49, "fuse is legible at half metre height")
		fuse.set_held(true)
		check(not visual.get_node("PickupLight").visible and fuse.visible, "holding removes beacon but retains model")
		fuse.attach_to_socket(room.objects.fuse_socket)
		check(not visual.get_node("PickupLight").visible and fuse.visible, "installed object has no loose pickup beacon")
		fuse.detach_from_socket()
		check(visual.get_node("PickupLight").visible, "removing object restores pickup beacon")
	var upper = game.rooms[4]
	game.camera.set_process(false)
	game.camera.global_position = upper.to_global(Vector3(24,5,11))
	game.camera.look_at(upper.to_global(Vector3(24,3.45,.5)))
	game.player.global_position = upper.to_global(Vector3(21.9,3.2,0))
	for node in upper.find_children("*", "Node", true, false):
		if node.get_script() != load("res://scripts/puzzles/foreground_arch.gd"): continue
		if absf(node.get_parent().position.x-24) > .01: continue
		node._process(1)
		check(node.transparency > .8, "nearby upper fuse fades obstructing foreground before player reaches pier")
		game.player.global_position.y = .03
		node._process(1)
		check(node.transparency < .01, "upper fuse does not fade foreground for player on different floor")
	# Every authored loose part has a model above its floor and one local cue.
	game.free()
	for theme in ["workshop","laundry","thread_vault","clocktower"]:
		game = load("res://scenes/chapters/full/"+theme+".tscn").instantiate()
		game.managed = true
		root.add_child(game)
		for bay in game.rooms:
			for entry in bay.spec.items:
				var item = bay.objects[entry.id]
				var cue = item.get_node("ItemPresentation")
				check(item.visible and cue.visual_bounds().position.y >= -.005, theme+"/"+entry.id+" has a visible model above floor")
				check(cue.get_child_count() == 1, "one pickup light per item")
		game.free()
	quit(1 if failures else 0)

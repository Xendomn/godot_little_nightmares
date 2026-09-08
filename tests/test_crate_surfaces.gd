extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1
func run() -> void:
	for id in ["workshop", "laundry", "thread_vault", "clocktower"]:
		var game = load("res://scenes/chapters/full/" + id + ".tscn").instantiate()
		root.add_child(game)
		await frames(4)
		game.start_game()
		game.set_process(false)
		game.player.set_physics_process(false)
		for room in game.rooms: room.set_physics_process(false)
		await frames(4)
		var actor = game.player
		actor.position = Vector3(-5, .03, 0)
		for room in game.rooms:
			var floor_body = room.get_node_or_null("Floor")
			if room.lift:
				for mesh in room.lift.get_children():
					if mesh is MeshInstance3D:
						var bounds: AABB = mesh.global_transform * mesh.get_aabb()
						check(bounds.end.y < -.005 and bounds.end.y > -.02, id + " lowered lift surface separate from boards and backing")
			if floor_body:
				var top := 100.0
				for mesh in floor_body.get_children():
					if mesh is MeshInstance3D:
						var bounds: AABB = mesh.global_transform * mesh.get_aabb()
						top = bounds.end.y
				check(top < -.015, id + " room %d backing surface below wood boards" % (room.index + 1))
				var floor_shape = floor_body.get_child(0)
				check(is_zero_approx(floor_body.position.y + floor_shape.shape.size.y * .5), "walking collision stays at zero")
			if room.objects.has("crate"):
				var crate = room.objects.crate
				crate.set_physics_process(false)
				for direction in [-1, 1]:
					crate.position = Vector3(38 if direction < 0 else 2, .03, 0)
					await frames(2)
					check(not crate.test_move(crate.global_transform, Vector3(direction * 36, 0, 0)), id + " room %d crate lane clear in direction %d" % [room.index + 1, direction])
		if id == "workshop":
			var room = game.rooms[0]
			room.restore_state(room.initial)
			var crate = room.objects.crate
			var fuse = room.objects.fuse
			actor.position = Vector3(6, .03, 0)
			room._physics_process(0)
			var hidden_position: Vector3 = fuse.position
			await frames(20)
			check(fuse.visible and fuse.collision_layer == 1 and fuse.is_in_group("puzzle_interactable"), "initial fuse remains real and interactive behind crate")
			check(fuse.position.y >= 0 and is_equal_approx(fuse.position.x, hidden_position.x), "initial fuse settles on floor without lateral movement")
			for i in range(150):
				crate.move_with_actor(actor, 1, 1.0 / 60)
				await physics_frame
			check(crate.position.x > 9.5 and actor.position.x > 8.5, "actual push carries player and crate past first pier")
			crate.position.x = 3
			room._physics_process(0)
			await frames(3)
			check(fuse.visible and fuse.collision_layer == 1 and fuse.is_in_group("puzzle_interactable"), "pulling crate reveals a physical pickable fuse")
			crate.position.x = 7
			actor.position = Vector3(2, .03, 0)
			room._physics_process(0)
			check(fuse.visible, "returning crate cannot hide a discovered fuse")
			await frames(2)
			var obstruction := KinematicCollision3D.new()
			if crate.test_move(crate.global_transform, Vector3(3, 0, 0), obstruction):
				print("Unexpected lane obstruction: ", obstruction.get_collider().get_path(), " at ", obstruction.get_position())
			check(not crate.test_move(crate.global_transform, Vector3(3, 0, 0)), "revealed fuse remains outside crate lane")
			var snapshot: Dictionary = room.capture_state().duplicate(true)
			room.restore_state(room.initial)
			room.restore_state(snapshot)
			check(fuse.visible and fuse.is_in_group("puzzle_interactable"), "discovery survives snapshot restore with crate returned")
			fuse.set_held(true)
			room._physics_process(0)
			check(fuse.visible and fuse.collision_layer == 0, "carried fuse stays visible without collision")
			fuse.attach_to_socket(room.objects.fuse_socket)
			room._physics_process(0)
			check(fuse.visible and fuse.collision_layer == 0, "installed fuse stays visible without collision")
			var legacy: Dictionary = room.capture_state().duplicate(true)
			legacy.erase("fuse_revealed")
			room.restore_state(room.initial)
			room.restore_state(legacy)
			check(fuse.visible and fuse.socket == room.objects.fuse_socket and fuse.collision_layer == 0, "old installed snapshot recovers discovery and socket state")
			room.restore_state(room.initial)
			check(fuse.visible and fuse.collision_layer == 1, "checkpoint reset restores real fuse behind crate")
			legacy = room.initial.duplicate(true)
			legacy.erase("fuse_revealed")
			legacy.objects.fuse.position = [8.2, .001, .5]
			room.restore_state(legacy)
			check(fuse.visible and is_equal_approx(fuse.position.z, -.95), "untouched legacy fuse migrates out of crate lane without discovery")
			legacy.objects.fuse.position = [10.0, .001, 1.2]
			room.restore_state(legacy)
			check(fuse.visible and fuse.collision_layer == 1, "legacy dropped fuse remains discovered and physical")
			legacy.objects.crate.position[0] = 3.0
			legacy.objects.fuse.position = [8.2, .001, .5]
			room.restore_state(legacy)
			check(fuse.visible and is_equal_approx(fuse.position.z, -.95), "legacy pulled crate reveals fuse safely beside lane")
			room.restore_state(room.initial)
			actor.position = Vector3(10, .03, 0)
			var control = actor.get_node("Interactions")
			fuse.set_held(true)
			fuse.position = Vector3(10.48, .73, 0)
			control.carried = fuse
			var world_snapshot: Dictionary = game.capture_world().duplicate(true)
			world_snapshot.rooms["0"].erase("fuse_revealed")
			game.restore_checkpoint("room_1", world_snapshot)
			check(control.carried == fuse and fuse.visible and fuse.held and fuse.collision_layer == 0, "legacy carried checkpoint restores visible held fuse")
			control.place_carried()
			room._physics_process(0)
			check(control.carried == null and fuse.visible and fuse.collision_layer == 1, "putting down restored fuse preserves discovery")
			for attempt in range(2):
				game.saved_snapshot = {}
				game.fail()
				await frames(45)
				check(not game.respawning and fuse.visible and fuse.collision_layer == 1, "repeated death restores physical fuse")
		game.queue_free()
		await frames(4)
	print("CRATE SURFACE FAILURES: ", failures)
	quit(1 if failures else 0)

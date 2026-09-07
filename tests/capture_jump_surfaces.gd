extends SceneTree
## Windowed: godot --path . --fixed-fps 60 --script tests/capture_jump_surfaces.gd
## Exercises real jump input and the gameplay camera; writes ignored artifacts.
const TestInput = preload("res://tests/input_events.gd")
const OUTPUT := "res://artifacts/jump-surfaces"
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func check(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + description)
	if not condition: failures += 1

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png")
	check(result == OK, "capture " + label)

func audit_floor_tops(game: Node3D) -> void:
	# Bounds are a candidate detector, not a general triangle intersection test.
	for room in game.rooms:
		var matches := {}
		for label in ["Floor", "Lift", "UpperWalk", "Island", "Span"]:
			for body in room.get_children():
				if not str(body.name).begins_with(label): continue
				for base in body.get_children():
					if not base is MeshInstance3D: continue
					var bounds: AABB = base.global_transform * base.mesh.get_aabb()
					for candidate in room.find_children("*", "MeshInstance3D", true, false):
						if candidate == base or not candidate.visible: continue
						var other: AABB = candidate.global_transform * candidate.mesh.get_aabb()
						if absf(bounds.end.y - other.end.y) > .0001: continue
						var overlap_x := minf(bounds.end.x, other.end.x) - maxf(bounds.position.x, other.position.x)
						var overlap_z := minf(bounds.end.z, other.end.z) - maxf(bounds.position.z, other.position.z)
						if overlap_x <= .001 or overlap_z <= .001: continue
						var key := str(body.name) + "/" + str(candidate.name).split("_")[0]
						matches[key] = int(matches.get(key, 0)) + 1
						if int(matches[key]) == 1:
							print("COPLANAR_CANDIDATE ", game.level_id, "/", room.name, "/", body.name,
								" top=", bounds.end.y, " mesh=", candidate.get_path(), " bounds=", other,
								" overlap_xz=", Vector2(overlap_x, overlap_z))
		if not matches.is_empty(): print("COPLANAR_COUNTS ", game.level_id, "/", room.name, " ", matches)

func capture_jumps(game: Node3D, label: String, position: Vector3) -> void:
	game.player.reset_to(position)
	game.player.enabled = true
	game.camera.instant = true
	await frames(45)
	check(game.player.is_on_floor(), label + " starts grounded")
	await shot(label + "-idle-before")
	for cycle in range(3):
		var prefix := label + "-jump-" + str(cycle + 1)
		var start_x: float = game.player.global_position.x
		if cycle == 1:
			TestInput.press("run")
			TestInput.press("right")
		TestInput.press("jump")
		await frames(2)
		TestInput.release("jump")
		check(game.player.velocity.y > 0, prefix + " real input launches player")
		await frames(8)
		await shot(prefix + "-rising")
		await frames(10)
		await shot(prefix + "-apex")
		if cycle == 1:
			TestInput.release("right")
			TestInput.release("run")
			check(game.player.global_position.x - start_x > .5, prefix + " running jump moves right")
		await frames(10)
		await shot(prefix + "-falling")
		for i in range(90):
			if game.player.is_on_floor(): break
			await frames(1)
		check(game.player.is_on_floor(), prefix + " lands")
		await shot(prefix + "-landed")
		await frames(8)
	for action in ["jump", "right", "run"]: TestInput.release(action)
	await frames(90)
	await shot(label + "-idle-after")
	check(game.player.is_on_floor(), label + " remains grounded after idle")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run this visual capture with a windowed rendering driver.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for id in ["workshop", "laundry", "thread_vault", "clocktower"]:
		var game = load("res://scenes/chapters/full/" + id + ".tscn").instantiate()
		root.add_child(game)
		await frames(4)
		game.start_game()
		# Keep actor physics and camera live; freeze puzzle hazards for repeatability.
		game.set_process(false)
		for room in game.rooms: room.set_physics_process(false)
		game.ui.hide()
		audit_floor_tops(game)
		await capture_jumps(game, id + "-floor", Vector3(10, .08, 0))
		# A second location covers the lowered lift where another top meets the floor.
		for room in game.rooms:
			if room.lift:
				await capture_jumps(game, id + "-lift", room.global_position + Vector3(21, .08, 0))
				break
		game.queue_free()
		await frames(5)
	print("Jump surface capture failures: ", failures)
	quit(1 if failures else 0)

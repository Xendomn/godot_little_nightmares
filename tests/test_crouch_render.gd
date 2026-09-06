extends SceneTree
## GPU-only regression: inspect the actual skin after AnimationTree blending.
var failures := 0
var lowest := INF
var highest := -INF
var game
var meshes: Array[MeshInstance3D] = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func gather(node: Node) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		gather(child)

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1

func measure() -> Vector2:
	await RenderingServer.frame_post_draw
	var bounds := Vector2(INF, -INF)
	for instance in meshes:
		var mesh := instance.bake_mesh_from_current_skeleton_pose()
		for surface in range(mesh.get_surface_count()):
			for vertex in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var y: float = (instance.global_transform * vertex).y
				bounds.x = minf(bounds.x, y)
				bounds.y = maxf(bounds.y, y)
	lowest = minf(lowest, bounds.x)
	highest = maxf(highest, bounds.y)
	return bounds

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + name + ".png")

func run() -> void:
	game = load("res://scenes/chapters/workshop.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	game.start_game()
	game.set_process(false)
	game.keeper.active = false
	game.player.position = Vector3(8, .03, 0)
	game.camera.set_process(false)
	game.camera.position = Vector3(8, 1.5, 4)
	game.camera.look_at(Vector3(8, .45, 0))
	game.ui.hide()
	gather(game.player.model)
	await frames(30)
	await capture("crouch-standing")
	Input.action_press("crouch")
	await frames(30)
	await capture("crouch-idle-fixed")
	for cycle in range(30):
		Input.action_press("right" if cycle % 2 == 0 else "left")
		await frames(10)
		var moving: Vector2 = await measure()
		Input.action_release("right")
		Input.action_release("left")
		await frames(4)
		var blending: Vector2 = await measure()
		await frames(10)
		var stopped: Vector2 = await measure()
		check(minf(moving.x, minf(blending.x, stopped.x)) >= -.022, "cycle %d visible mesh above floor" % cycle)
		check(maxf(moving.y, maxf(blending.y, stopped.y)) <= .67, "cycle %d remains crouched across movement stop" % cycle)
	await capture("crouch-after-30-stops")
	game.player.position = Vector3(21.5, .03, 0)
	game.camera.position = Vector3(21.5, 1.5, 4)
	game.camera.look_at(Vector3(21.5, .45, 0))
	await frames(20)
	Input.action_release("crouch")
	await frames(20)
	check(game.player.crouching, "duct keeps crouch after Ctrl release")
	var duct: Vector2 = await measure()
	check(duct.x >= -.022 and duct.y <= .67, "duct mesh stays within grounded crouch bounds")
	await capture("crouch-duct-fixed")
	print("GPU CROUCH bounds=", lowest, "..", highest, " meshes=", meshes.size(), " failures=", failures)
	game.queue_free()
	await frames(4)
	quit(1 if failures else 0)

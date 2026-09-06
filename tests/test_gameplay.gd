extends SceneTree
const TestInput = preload("res://tests/input_events.gd")

var game
var failures: int = 0
var visual: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + description)
	if not condition:
		failures += 1

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func action(key: String, pressed: bool) -> void:
	if pressed:
		TestInput.press(key)
	else:
		TestInput.release(key)

func tap(key: String) -> void:
	action(key, true)
	await frames(2)
	action(key, false)

func move_to(x: float, max_frames: int = 600) -> bool:
	var direction := "right" if game.player.position.x < x else "left"
	action(direction, true)
	for i in range(max_frames):
		await frames(1)
		if absf(game.player.position.x - x) < 0.09:
			action(direction, false)
			await frames(8)
			return true
		if game.respawning:
			break
	action(direction, false)
	print("MOVE STOP x=", game.player.position, " target=", x)
	return false

func depth_to(z: float) -> void:
	var direction := "depth_down" if game.player.position.z < z else "depth_up"
	action(direction, true)
	for i in range(240):
		await frames(1)
		if absf(game.player.position.z - z) < 0.06:
			break
	action(direction, false)
	await frames(8)

func capture(title: String) -> void:
	if not visual:
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + title + ".png")

func run() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	game = load("res://scenes/chapters/workshop.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	check(game.ui.menu.visible and not game.player.enabled, "menu gates player input")
	game.start_game()
	await frames(20)
	check(game.player.is_on_floor(), "player settles on floor")
	check(await move_to(5.15), "approach movable crate")
	action("interact", true)
	action("right", true)
	await frames(235)
	action("right", false)
	action("interact", false)
	await frames(12)
	check(game.crate.position.x > 9.4, "held interaction physically pushes crate beside bench")
	print("PUSH positions=", game.player.position, " / ", game.crate.position)
	action("right", true)
	await tap("jump")
	await frames(21)
	action("right", false)
	await frames(36)
	check(game.player.position.y > 1.0 and game.player.is_on_floor(), "first jump lands on movable crate")
	print("CRATE landing=", game.player.position)
	action("right", true)
	await tap("jump")
	await frames(37)
	action("right", false)
	await frames(25)
	check(game.player.position.y > 1.9 and game.player.is_on_floor(), "second jump lands on workbench")
	await move_to(12.6)
	await tap("interact")
	check(game.state.has_fuse, "pickup reachable on workbench through real input")
	await capture("01-workbench")
	await move_to(19.2)
	await move_to(20.6, 100)
	check(game.player.position.x < 19.9, "standing player is blocked by low duct")
	action("crouch", true)
	check(await move_to(24.8), "crouched player traverses low duct")
	action("crouch", false)
	await frames(10)
	check(game.state.checkpoint == 1, "crossing room with fuse records checkpoint")
	game.fail()
	await frames(110)
	check(not game.respawning and game.state.has_fuse and game.player.position.x > 24, "workshop death restores player and carried fuse")
	await move_to(29.8)
	await depth_to(-0.25)
	await tap("interact")
	check(game.state.fuse_installed and not game.state.has_fuse, "panel installs fuse through input")
	await capture("02-assembly")
	# Characterization: the table must occlude the keeper's eye ray.
	game.player.position = Vector3(36.5, 0.05, 0.7)
	game.player.crouching = true
	game.keeper.position = Vector3(33.5, 0.05, -1.3)
	game.keeper.facing = 1
	await physics_frame
	check(not game.keeper.can_see_player(), "table occludes crouched player from keeper")
	game.player.position = Vector3(35, 0.05, -1.3)
	game.player.crouching = false
	check(game.keeper.can_see_player(), "unobstructed player inside field of view is visible")
	game.keeper.facing = -1
	check(not game.keeper.can_see_player(), "player behind keeper is outside field of view")
	# Isolate final gauntlet from patrol timing for deterministic collision coverage.
	game.player.position = Vector3(50, 0.05, 0)
	game.keeper.position = Vector3(33, 0.05, -1.3)
	await frames(8)
	await tap("interact")
	check(game.state.power_on and game.keeper.finale, "remote lever starts chase and opens exit")
	action("run", true)
	await move_to(55)
	check(game.state.checkpoint == 2, "chase entrance creates powered checkpoint")
	game.fail()
	await frames(110)
	check(game.state.power_on and game.player.position.x >= 55, "chase death preserves open gate and power")
	for edge in [61.1, 69.1, 77.1]:
		if edge > 70:
			await move_to(72.55)
			action("crouch", true)
			await move_to(75.5)
			action("crouch", false)
		await move_to(edge)
		action("right", true)
		await tap("jump")
		await frames(40)
		action("right", false)
		await frames(6)
		check(not game.respawning and game.player.position.x > edge + 2, "running jump clears gap at " + str(edge))
	await capture("03-chase")
	await move_to(86.1)
	action("run", false)
	await frames(120)
	check(game.state.completed and game.ui.ending.visible, "exit produces complete ending")
	await capture("04-ending")
	game.start_game()
	game.player.position.y = -5
	await frames(110)
	check(game.state.checkpoint == 0 and not game.state.has_fuse and game.player.position.y > -0.1 and absf(game.player.position.x - 2) < 0.1, "first-room fall resets puzzle without stale progress")
	game.queue_free()
	await frames(3)
	# Fixed-FPS headless runs outrun the real audio thread; let it release playback.
	OS.delay_msec(100)
	print("GAMEPLAY FAILURES: ", failures)
	quit(1 if failures else 0)

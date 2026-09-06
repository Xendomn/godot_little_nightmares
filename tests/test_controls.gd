extends SceneTree

var game
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1

func frames(n: int) -> void:
	for i in range(n):
		await process_frame

func press_pause() -> void:
	var event := InputEventAction.new()
	event.action = "pause"
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventAction.new()
	event.action = "pause"
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.start_game()
	await press_pause()
	check(paused and game.ui.pause_menu.visible, "Escape opens pause menu")
	var original: Vector3 = game.player.position
	Input.action_press("right")
	await frames(20)
	check(game.player.position.is_equal_approx(original), "paused game freezes player physics")
	Input.action_release("right")
	await press_pause()
	check(not paused and not game.ui.pause_menu.visible, "Escape resumes from paused tree")
	game.player.position = Vector3(12.8, 0.03, 0.25)
	await frames(5)
	game.update_prompt()
	check(game.nearest == null, "solid workbench blocks pickup from below")
	game.player.position = Vector3(21.5, 0.03, 0)
	Input.action_press("crouch")
	await frames(8)
	Input.action_release("crouch")
	await frames(8)
	check(game.player.crouching, "releasing crouch inside duct cannot expand into ceiling")
	game.start_game()
	game.state.collect_fuse()
	game.state.enter_checkpoint(1)
	game.state.install_fuse()
	game.fail()
	await frames(4)
	game.start_game()
	await frames(120)
	check(game.state.checkpoint == 0 and not game.state.has_fuse and not game.respawning, "restart cancels outstanding death transition")
	game.queue_free()
	await frames(3)
	OS.delay_msec(100)
	print("CONTROL FAILURES: ", failures)
	quit(1 if failures else 0)

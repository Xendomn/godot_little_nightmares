extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count): await process_frame
func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	var game = load("res://scenes/chapters/workshop.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	game.start_game()
	game.set_process(false)
	for pair in [[KEY_A, KEY_LEFT], [KEY_D, KEY_RIGHT], [KEY_W, KEY_UP], [KEY_S, KEY_DOWN]]:
		var results: Array[Vector3] = []
		for code in pair:
			game.player.reset_to(Vector3(3, .05, 0))
			await frames(20)
			key(code, true)
			await frames(24)
			key(code, false)
			await frames(8)
			results.append(game.player.position)
		var ok := results[0].distance_to(results[1]) < .002 and results[0].distance_to(Vector3(3, 0, 0)) > .2
		print(("PASS: " if ok else "FAIL: ") + "physical movement equivalence " + str(pair))
		if not ok: failures += 1
	game.queue_free()
	await frames(4)
	OS.delay_msec(120)
	quit(1 if failures else 0)

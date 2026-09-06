extends SceneTree
## Render a real physics pursuit around the first assembly table.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/chapters/workshop.tscn").instantiate()
	root.add_child(game)
	for i in range(4):
		await process_frame
	game.start_game()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.position = Vector3(39.7, .03, 1.15)
	game.keeper.position = Vector3(33.3, .03, 1.15)
	game.camera.set_process(false)
	game.camera.position = Vector3(36.5, 6.5, 10)
	game.camera.look_at(Vector3(36.5, .8, 0))
	game.ui.hide()
	var crossed := false
	for i in range(480):
		game.keeper.active = true
		game.keeper.mode = game.keeper.Mode.CHASE
		game.keeper.suspicion = 1
		game.keeper.lost_time = 0
		game.keeper.last_seen = game.player.position
		game.keeper.grace = 10
		await process_frame
		crossed = crossed or game.keeper.position.x > 39
		if i in [60, 150, 300]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/keeper-route-%d.png" % i)
	print(("PASS: " if crossed else "FAIL: ") + "rendered keeper bypasses assembly table")
	game.queue_free()
	for i in range(4):
		await process_frame
	quit(0 if crossed else 1)

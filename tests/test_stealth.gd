extends SceneTree

var game

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame
		await process_frame

func run() -> void:
	game = load("res://scenes/chapters/workshop.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.start_game()
	game.state.enter_checkpoint(1)
	game.restore_world()
	game.state.install_fuse()
	game.refresh_world()
	game.player.position = Vector3(30, 0.05, 1.15)
	Input.action_press("crouch")
	Input.action_press("right")
	var caught_at := -1.0
	for i in range(600):
		await frames(1)
		if game.respawning:
			caught_at = game.player.position.x
			break
		if game.player.position.x > 36.7:
			break
	Input.action_release("right")
	print("HIDE: ", game.player.position, " keeper=", game.keeper.position, " mode=", game.keeper.mode)
	for i in range(2400):
		await frames(1)
		if game.respawning:
			caught_at = game.player.position.x
			break
		if game.keeper.position.x < 34 and game.keeper.facing < 0 and game.keeper.mode == 0:
			break
	print("LEAVE HIDE: ", game.player.position, " keeper=", game.keeper.position, " mode=", game.keeper.mode)
	Input.action_press("right")
	for i in range(750):
		await frames(1)
		if game.respawning:
			caught_at = game.player.position.x
			break
		if game.player.position.x > 49.7:
			break
	Input.action_release("right")
	Input.action_release("crouch")
	print("STEALTH: x=", game.player.position.x, " caught_at=", caught_at, " keeper=", game.keeper.position, " state=", game.keeper.mode)
	var success: bool = caught_at < 0 and game.player.position.x > 49.7
	game.queue_free()
	await frames(3)
	OS.delay_msec(100)
	quit(0 if success else 1)

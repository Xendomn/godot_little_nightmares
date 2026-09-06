extends "res://tests/test_expansion.gd"

func jump_to(target: float) -> void:
	TestInput.press("jump")
	await move_x(target)
	TestInput.release("jump")
	await frames(8)

func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/" + name + ".png")

func run() -> void:
	await open_level("laundry")
	game.restore_checkpoint(2)
	await depth(1.15)
	await move_x(37, "crouch")
	await capture("laundry-stealth")
	TestInput.press("crouch")
	for i in range(850):
		await physics_frame
		if game.keeper.position.x < 36.7 and game.keeper.facing < 0:
			break
	await move_x(49, "crouch")
	check(not game.respawning and game.player.position.x > 48, "laundry table concealment route")
	for x in [52, 55]:
		await move_x(x - 1.2)
		var hazard = game.world.get_node("Steam" + str(x))
		for i in range(400):
			await physics_frame
			if not hazard.dangerous and fmod(hazard.time + hazard.phase_offset, hazard.period) < hazard.period - .8:
				break
		await move_x(x + 1.2)
	await move_x(62)
	check(not game.playing and not game.respawning, "laundry timed steam corridor reaches exit")
	await open_level("thread_vault")
	game.restore_checkpoint(2)
	await move_x(40.6, "")
	await interact()
	check(game.keeper.distraction > 0, "bell attracts keeper through player input")
	await move_x(46, "crouch")
	await capture("vault-stealth")
	TestInput.press("crouch")
	for i in range(900):
		await physics_frame
		if game.keeper.position.x < 42:
			break
	await move_x(59, "crouch")
	await move_x(62)
	check(not game.playing and not game.respawning, "vault decoy and table route reaches exit")
	await open_level("clocktower")
	game.restore_checkpoint(2)
	await frames(15)
	await capture("clocktower-chase")
	await move_x(42.2)
	await jump_to(45)
	check(game.player.position.x > 44.3 and not game.respawning, "clock chase first gap")
	await move_x(50.2)
	await jump_to(53)
	await move_x(53.9)
	await move_x(58, "crouch")
	check(game.player.position.x > 57.5 and not game.respawning, "clock chase crouch passage")
	await move_x(58.3)
	await jump_to(61)
	await move_x(69)
	await frames(110)
	check(not game.playing and game.ui.ending.visible and not game.respawning, "three jumps and tunnel reach final dawn ending")
	await capture("dawn-ending")
	game.queue_free()
	await frames(4)
	OS.delay_msec(120)
	print("ROUTE FAILURES: ", failures)
	quit(1 if failures else 0)

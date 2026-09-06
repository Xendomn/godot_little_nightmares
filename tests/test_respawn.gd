extends "res://tests/test_expansion.gd"
func run() -> void:
	for id in ["workshop", "laundry", "thread_vault", "clocktower"]:
		await open_level(id)
		game.restore_checkpoint(2)
		game.fail()
		Input.action_press("right")
		await frames(70)
		check(game.respawning and not game.player.enabled, id + " input remains disabled during fade-in")
		var restored: Vector3 = game.player.position
		await frames(14)
		check(game.player.position.is_equal_approx(restored), id + " held movement cannot move respawned actor behind fade")
		await frames(22)
		Input.action_release("right")
		check(not game.respawning and game.player.enabled, id + " controls activate after fade finishes")
	game.queue_free()
	await frames(4)
	OS.delay_msec(120)
	print("RESPAWN FAILURES: ", failures)
	quit(1 if failures else 0)

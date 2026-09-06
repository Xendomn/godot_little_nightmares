extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1
func run() -> void:
	var game = load("res://scenes/chapters/workshop.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game()
	for actor in [game.player, game.keeper]:
		var driver = actor.visual_driver
		check(driver.skeleton != null and driver.head_bone >= 0, str(actor.name) + " imported skeleton and head sensor")
		check(driver.spring != null, str(actor.name) + " native cloth spring chain")
		var required := ["idle", "walk", "run", "jump", "fall", "land", "crouch", "crouch_walk", "push", "pickup", "interact", "caught"] if actor == game.player else ["idle", "walk", "alert", "listen", "chase", "grab", "stumble"]
		for clip in required:
			check(driver.clips.has(clip), str(actor.name) + " clip " + clip)
			if clip in ["crouch", "fall", "push"]:
				check(driver.animator.get_animation(driver.clips[clip]).loop_mode == Animation.LOOP_NONE, "single action holds final pose " + clip)
			if actor == game.player:
				actor.enabled = false
			else:
				actor.active = false
			# StateMachinePlayback travels through actual imported AnimationTree tracks.
			driver.locked_time = 0
			driver.play(clip, .4)
			for i in range(16):
				await process_frame
			check(driver.playback.get_current_node() == clip, "animation transition " + clip)
	game.player.reset_to(Vector3(21.5, .03, 0))
	Input.action_press("crouch")
	for i in range(24):
		await process_frame
	check(game.player.crouching and game.player.model.scale == Vector3.ONE, "crouch uses bones with unchanged model scale")
	Input.action_release("crouch")
	game.queue_free()
	await process_frame
	await process_frame
	OS.delay_msec(120)
	print("RIG FAILURES: ", failures)
	quit(1 if failures else 0)

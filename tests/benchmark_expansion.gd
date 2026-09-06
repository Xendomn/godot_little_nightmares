extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var results: Array = []
	for id in ["workshop", "laundry", "thread_vault", "clocktower"]:
		var game = load("res://scenes/chapters/" + id + ".tscn").instantiate()
		root.add_child(game)
		await process_frame
		game.start_game()
		game.restore_checkpoint(2 if id != "workshop" else 1)
		var center := {"workshop": 36.5, "laundry": 37.0, "thread_vault": 46.0, "clocktower": 37.0}
		game.player.position = Vector3(center[id], 2.65 if id in ["laundry", "clocktower"] else .05, 1.15)
		game.camera.instant = true
		Input.action_press("crouch")
		# Keep the character moving under cover while animation, AI and sound run.
		game.keeper.caught.disconnect(game.fail)
		var times: Array[float] = []
		var previous := Time.get_ticks_usec()
		for i in range(420):
			Input.action_release("left")
			Input.action_release("right")
			Input.action_press("right" if (i / 45) % 2 == 0 else "left")
			await process_frame
			var now := Time.get_ticks_usec()
			if i >= 180:
				times.append((now - previous) / 1000.0)
			previous = now
		Input.action_release("left")
		Input.action_release("right")
		Input.action_release("crouch")
		var sum := 0.0
		for time in times:
			sum += time
		times.sort()
		var result := {"chapter": id, "average_fps": 1000.0 * times.size() / sum, "p95_frame_ms": times[int(times.size() * .95)], "gpu": RenderingServer.get_video_adapter_name(), "resolution": str(root.size)}
		results.append(result)
		print("PERFORMANCE ", JSON.stringify(result))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/benchmark-" + id + ".png")
		game.queue_free()
		await process_frame
		await process_frame
	var file := FileAccess.open("res://artifacts/expansion-performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	OS.delay_msec(120)
	quit()

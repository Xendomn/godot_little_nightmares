extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var results: Array = []
	for entry in [["workshop", "SwitchVisual", 51.0, 0.0], ["laundry", "Drain/Visual", 7.0, 0.0], ["thread_vault", "Bell/Visual", 41.0, 0.0], ["clocktower", "LastBell", 31.5, 2.6]]:
		var game = load("res://scenes/chapters/" + entry[0] + ".tscn").instantiate()
		root.add_child(game)
		await process_frame
		game.start_game()
		game.set_process(false)
		game.player.position = Vector3(entry[2] - 1.5, entry[3] + .05, .1)
		game.camera.instant = true
		var prop = game.get_node("World/" + entry[1])
		var times: Array[float] = []
		var previous := Time.get_ticks_usec()
		for i in range(480):
			if i % 90 == 0:
				prop.set_active(not prop.active)
				prop.play_feedback()
			await process_frame
			var now := Time.get_ticks_usec()
			if i >= 180: times.append((now - previous) / 1000.0)
			previous = now
		var total := 0.0
		for value in times: total += value
		times.sort()
		var result := {"chapter": entry[0], "prop": entry[1], "average_fps": 1000 * times.size() / total, "p95_frame_ms": times[int(times.size() * .95)], "resolution": str(root.size), "gpu": RenderingServer.get_video_adapter_name()}
		results.append(result)
		print("PROP PERFORMANCE ", JSON.stringify(result))
		game.queue_free()
		await process_frame
		await process_frame
	var file := FileAccess.open("res://artifacts/props-performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	OS.delay_msec(120)
	quit()

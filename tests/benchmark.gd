extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/chapters/workshop.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game()
	var report: Array = []
	for x in [8, 37, 67]:
		game.player.enabled = false
		game.playing = false
		game.player.position = Vector3(x, 0.03, 0)
		game.camera.instant = true
		game.camera.chase = x > 54
		for i in range(150):
			await process_frame
		var start := Time.get_ticks_usec()
		for i in range(240):
			await process_frame
		var seconds := (Time.get_ticks_usec() - start) / 1000000.0
		var result := {"room_x": x, "fps": 240.0 / seconds, "gpu": RenderingServer.get_video_adapter_name(), "viewport": str(root.size)}
		report.append(result)
		print("BENCHMARK ", JSON.stringify(result))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/room-" + str(x) + ".png")
	var file := FileAccess.open("res://artifacts/benchmark.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	game.queue_free()
	await process_frame
	await process_frame
	quit()

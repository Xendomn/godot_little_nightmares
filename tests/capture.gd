extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/chapters/workshop.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() else "menu"
	if mode != "menu":
		game.start_game()
		game.player.position = Vector3(float(args[1]) if args.size() > 1 else 8.0, 0.1, 0)
		game.camera.instant = true
	for i in range(80):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://artifacts/" + mode + ".png"
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path, " renderer=", RenderingServer.get_video_adapter_name(), " fps=", Engine.get_frames_per_second())
	game.queue_free()
	await process_frame
	await process_frame
	quit()

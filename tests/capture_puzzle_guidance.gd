extends SceneTree
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func shot(label: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/guidance-" + label + ".png")
func run() -> void:
	for theme in ["workshop","laundry","thread_vault"]:
		var game = load("res://scenes/chapters/full/"+theme+".tscn").instantiate()
		game.managed = true
		root.add_child(game)
		game.start_game()
		await frames(4)
		game.set_process(false)
		game.player.set_physics_process(false)
		game.camera.set_process(false)
		game.ui.hide()
		for room in game.rooms:
			room.set_physics_process(false)
			if room.get_node_or_null("PuzzlePresentation") == null:
				var presentation = load("res://scripts/puzzles/puzzle_presentation.gd").new()
				room.add_child(presentation)
				presentation.setup(room)
		var indices: Array = [2,3] if theme == "workshop" else ([1] if theme == "laundry" else [4])
		for index in indices:
			var room = game.rooms[index]
			game.active_room = index
			game.refresh()
			var x := 26.0 if index == 2 else (23.0 if theme == "workshop" else (18.0 if theme == "laundry" else 9.0))
			game.player.global_position = room.to_global(Vector3(x-2,.03,.4))
			game.camera.instant = true
			game.camera.set_process(true)
			game.ui.show()
			await shot(theme+str(index)+"-gameplay-idle")
			game.ui.hide()
			game.camera.set_process(false)
			game.camera.global_position = room.to_global(Vector3(x+2,3.6,7))
			game.camera.look_at(room.to_global(Vector3(x,.55,0)))
			await shot(theme+str(index)+"-idle")
			if room.objects.has("crate"):
				room.objects.crate.position = Vector3(x,.03,0)
				room.get_node("PuzzlePresentation").update(0)
				await shot(theme+str(index)+"-pressed")
		var room = game.rooms[0]
		game.player.global_position = room.to_global(Vector3(39,.03,0))
		game.camera.global_position = room.to_global(Vector3(43,3.0,8))
		game.camera.look_at(room.to_global(Vector3(41,1.3,0)))
		room.completed = true
		room.gate.position.y = 6.3
		room.get_node("PuzzlePresentation").update(0)
		await shot(theme+"-exit")
		game.free()
		await frames(3)
	quit()

extends SceneTree
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func shot(label: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/water-" + label + ".png")
func run() -> void:
	var game = load("res://scenes/chapters/full/laundry.tscn").instantiate()
	game.managed = true
	root.add_child(game)
	game.start_game()
	await frames(6)
	game.set_process(false)
	game.player.set_physics_process(false)
	for room in game.rooms: room.set_physics_process(false)
	for index in [0,1,2,4]:
		var room = game.rooms[index]
		game.active_room = index
		game.refresh()
		game.player.global_position = room.to_global(Vector3(20,.03,.8))
		game.camera.instant = true
		game.camera.set_process(true)
		for level in [-.05,.8,1.9]:
			room.water.set_water_level(level)
			await shot("room%d-level%.2f" % [index+1,level])
		game.ui.hide()
		game.camera.set_process(false)
		game.camera.global_position = room.to_global(Vector3(33,3.0,12))
		game.camera.look_at(room.to_global(Vector3(24,.8,0)))
		await shot("room%d-side" % (index+1))
		game.ui.show()
	game.free()
	quit()

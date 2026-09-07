extends SceneTree
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count): await process_frame
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/repair-" + label + ".png")
func run() -> void:
	for id in ["workshop","laundry","thread_vault","clocktower"]:
		var game = load("res://scenes/chapters/full/"+id+".tscn").instantiate()
		root.add_child(game)
		await frames(4)
		game.start_game()
		game.set_process(false)
		for room in game.rooms: room.set_physics_process(false)
		game.player.set_physics_process(false)
		game.camera.set_process(false)
		game.ui.hide()
		game.player.position = Vector3(8,.03,0)
		game.camera.set_process(true)
		game.camera.instant = true
		await frames(20)
		await shot(id+"-arch")
		game.camera.set_process(false)
		if id == "workshop":
			var room = game.rooms[1]
			var actor = game.player
			var control = actor.get_node("Interactions")
			room.ladder.visible = true
			for entry in [["bottom",.05],["middle",1.5],["top",3.20]]:
				control.cancel_interaction()
				actor.global_position = room.ladder.global_position + Vector3(0,entry[1],0)
				control.attach_ladder(room.ladder)
				actor.visual_driver.advance_climb(.2)
				game.camera.position = actor.global_position + Vector3(2.3,1.25,4)
				game.camera.look_at(actor.global_position+Vector3(0,.9,-.2))
				await frames(20)
				await shot("ladder-"+entry[0])
				if entry[0] == "middle":
					control.tick(1.0/60)
					game.ui.show()
					var hints = root.get_node("InputHints")
					for pad in [false,true]:
						hints.select_device(pad,0)
						game.ui.prompt.text = hints.format_text(control.prompt_text)
						await frames(3)
						await shot("ladder-hint-"+("controller" if pad else "keyboard"))
					hints.select_device(false)
					game.ui.hide()
				var skeleton: Skeleton3D = actor.visual_driver.skeleton
				for bone in ["Hand.L","Hand.R"]:
					print(entry[0]," ",bone," ",skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin-actor.global_position)
			Input.action_press("depth_up")
			for i in range(40):
				control.tick(1.0/60)
				await frames(1)
			Input.action_release("depth_up")
			await frames(12)
			await shot("ladder-landed")
		game.queue_free()
		await frames(5)
	OS.delay_msec(150)
	quit()

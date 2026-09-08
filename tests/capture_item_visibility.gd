extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for theme in ["workshop","laundry","thread_vault","clocktower"]:
		var game = load("res://scenes/chapters/full/"+theme+".tscn").instantiate()
		game.managed = true
		root.add_child(game)
		game.start_game()
		game.set_process(false)
		game.player.set_physics_process(false)
		for room in game.rooms: room.set_physics_process(false)
		for i in 100: await physics_frame
		for room in game.rooms:
			for entry in room.spec.items:
				var item = room.objects[entry.id]
				var bounds := AABB()
				var first := true
				for mesh in item.find_children("*","MeshInstance3D",true,false):
					var local: AABB = item.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
					bounds = local if first else bounds.merge(local)
					first = false
				print("ITEM ",theme,"/",room.index+1," ",entry.id," pos=",item.position," visible=",item.visible," local_bounds=",bounds)
				if DisplayServer.get_name() != "headless" and entry.id in ["fuse","fuse_a","fuse_b","wheel","weight_a","gear"]:
					game.active_room = room.index
					game.refresh()
					game.player.global_position = room.to_global(Vector3(item.position.x-2,item.position.y+.03,.6))
					if room.lift and item.position.y > 2: room.lift.position.y = 3.11
					game.camera.instant = true
					for i in 14: await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://artifacts/item-after-"+theme+str(room.index+1)+"-"+entry.id+".png")
				if theme == "workshop" and room.index == 0:
					for x in [8.5,5.5]:
						room.objects.crate.position.x = x
						room.update_fuse_presence()
						for i in 14: await process_frame
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png("res://artifacts/item-after-first-crate-"+str(x)+".png")
		game.free()
		await process_frame
	quit()

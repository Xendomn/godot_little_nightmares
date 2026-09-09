extends SceneTree
## Windowed visual fixtures, not evidence of solving or blind play.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/puzzle-upgrade")
	for id in ["workshop","laundry","thread_vault","clocktower"]:
		var chapter = load("res://scenes/chapters/full/"+id+".tscn").instantiate()
		chapter.managed=true
		root.add_child(chapter)
		chapter.start_game()
		chapter.set_process(false)
		chapter.player.set_physics_process(false)
		for room in chapter.rooms: room.set_physics_process(false)
		var indices: Array = {"workshop":[2,3],"laundry":[1,2,4,5],"thread_vault":[1,3,4],"clocktower":[2,3,4]}[id]
		for index in indices:
			var room = chapter.rooms[index]
			chapter.active_room=index
			chapter.refresh()
			chapter.player.position=room.position+Vector3(24,.03,1.3)
			if id=="workshop" and index==3:
				room.objects.crate.position=Vector3(23,.001,0)
				room.objects.crate.set_physics_process(false)
				room.machines.ram_height=1.9
				room.machines.tick(0)
			if id=="laundry" and index==5:
				room.objects.timing.state=2
				room.machines.cycles[0].time=1.5
			if id=="laundry" and index in [1,2,4]:
				var water = room.machines.water_machine
				water.circuit.left=1.9
				water.circuit.right=0
				if index==1:
					room.objects.roof_hatch.state=1
					room.objects.crate.position=Vector3(21.3,1.65,0)
					room.objects.crate.set_physics_process(false)
				water.refresh(0,true)
				chapter.player.position.y=3.22
			if id=="clocktower" and index>=3:
				room.machines.shafts.fast=1.4
				room.machines.shafts.slow=2.7
			if id=="thread_vault" and index==4: chapter.update_bell_encounter(room,0)
			room.machines.refresh_visuals()
			room.presentation.update(0)
			chapter.camera.set_process(false)
			chapter.camera.position=room.position+Vector3(25,7,22)
			chapter.camera.look_at(room.position+Vector3(25,2,0))
			for i in 12: await process_frame
			await RenderingServer.frame_post_draw
			var path := "res://artifacts/puzzle-upgrade/%s-%d.png" % [id,index+1]
			check_save(root.get_texture().get_image().save_png(path),path)
		chapter.free()
		await process_frame
	quit()
func check_save(error: Error, path: String) -> void:
	if error!=OK:
		push_error("Screenshot failed: "+path)
		quit(1)
	else: print("CAPTURED "+path)

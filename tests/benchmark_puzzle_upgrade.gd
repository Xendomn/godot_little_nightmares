extends SceneTree
## Representative live mechanism scenes; fixed safe camera/player fixtures.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report := {"renderer":RenderingServer.get_video_adapter_name(),"resolution":[root.size.x,root.size.y],"chapters":[]}
	for id in ["workshop","laundry","thread_vault","clocktower"]:
		var chapter=load("res://scenes/chapters/full/"+id+".tscn").instantiate()
		chapter.managed=true
		root.add_child(chapter)
		chapter.start_game()
		var index: int={"workshop":3,"laundry":2,"thread_vault":1,"clocktower":2}[id]
		chapter.restore_checkpoint("room_"+str(index+1))
		chapter.player.set_physics_process(false)
		var point: Vector3={"workshop":Vector3(26.5,.03,0),"laundry":Vector3(26,3.22,0),"thread_vault":Vector3(24,1.62,0),"clocktower":Vector3(26,.03,0)}[id]
		chapter.player.position=chapter.rooms[index].position+point
		if id=="laundry": chapter.rooms[index].objects.transfer.state=1
		for i in 120: await process_frame
		var samples: Array[float]=[]
		var before := Time.get_ticks_usec()
		for i in 360:
			await process_frame
			var now := Time.get_ticks_usec()
			samples.append(float(now-before)/1000)
			before=now
		samples.sort()
		var total := 0.0
		for value in samples: total+=value
		report.chapters.append({"id":id,"room":index+1,"fps":1000/(total/samples.size()),"p95_ms":samples[int(samples.size()*.95)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
		chapter.free()
		await process_frame
	DirAccess.make_dir_recursive_absolute("res://artifacts/puzzle-upgrade")
	var file := FileAccess.open("res://artifacts/puzzle-upgrade/performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit()

extends SceneTree
var samples: Array[float] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report := {"renderer":RenderingServer.get_video_adapter_name(),"resolution":[root.size.x,root.size.y],"chapters":[]}
	for id in ["workshop","laundry","thread_vault","clocktower"]:
		var chapter = load("res://scenes/chapters/full/"+id+".tscn").instantiate()
		chapter.managed = true
		root.add_child(chapter)
		chapter.start_game()
		chapter.restore_checkpoint("room_5")
		chapter.player.position.x += 18
		for _i in 90: await process_frame
		samples.clear()
		var before := Time.get_ticks_usec()
		for _i in 240:
			await process_frame
			var now := Time.get_ticks_usec()
			samples.append(float(now-before)/1000)
			before = now
		samples.sort()
		var total := 0.0
		for value in samples: total += value
		report.chapters.append({"id":id,"fps":1000/(total/samples.size()),"p95_ms":samples[int(samples.size()*.95)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
		chapter.queue_free()
		await process_frame
	var file := FileAccess.open("res://artifacts/expanded-campaign/performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit()

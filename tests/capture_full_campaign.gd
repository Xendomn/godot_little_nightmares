extends SceneTree
var chapter: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for id in ["workshop","laundry","thread_vault","clocktower"]:
		chapter = load("res://scenes/chapters/full/"+id+".tscn").instantiate()
		chapter.managed = true
		root.add_child(chapter)
		chapter.start_game()
		chapter.restore_checkpoint("room_3")
		chapter.player.position.x += 17
		for _i in 90: await process_frame
		root.get_texture().get_image().save_png("res://artifacts/expanded-campaign/"+id+".png")
		print("CAPTURED "+id)
		chapter.queue_free()
		await process_frame
	quit()

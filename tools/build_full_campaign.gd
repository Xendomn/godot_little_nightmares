extends SceneTree
## Materializes authored puzzle specs as individually editable Godot room scenes.
func _initialize() -> void:
	var content = load("res://scripts/puzzles/campaign_content.gd")
	for id in content.IDS:
		var directory := "res://scenes/chapters/full/"+str(id)
		DirAccess.make_dir_recursive_absolute(directory)
		var specifications: Array = content.rooms(id)
		for i in specifications.size():
			var room = load("res://scripts/puzzles/puzzle_room.gd").new()
			room.name = "Room"+str(i+1)
			room.spec = specifications[i]
			room.theme = id
			room.index = i
			var packed := PackedScene.new()
			if packed.pack(room) != OK or ResourceSaver.save(packed,directory+"/room_"+str(i+1)+".tscn") != OK:
				push_error("Cannot save authored room")
				quit(1)
				return
			room.free()
		var definition = load("res://resources/levels/"+str(id)+".tres")
		definition.scene_path = "res://scenes/chapters/full/"+str(id)+".tscn"
		if ResourceSaver.save(definition,"res://resources/levels/"+str(id)+".tres") != OK:
			quit(1)
			return
	print("BUILT 24 AUTHORED ROOMS")
	quit()

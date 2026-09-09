extends SceneTree
var failures := 0
func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value: failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var script = load("res://scripts/puzzles/puzzle_presentation.gd")
	if script == null:
		check(false, "puzzle presentation exists")
		quit(1)
		return
	var content = load("res://scripts/puzzles/campaign_content.gd")
	var plate_count := 0
	for theme in content.IDS:
		var specs: Array = content.rooms(theme)
		for i in specs.size():
			var room = load("res://scripts/puzzles/puzzle_room.gd").new()
			room.spec = specs[i]
			room.theme = theme
			room.index = i
			root.add_child(room)
			room.set_physics_process(false)
			var presentation = room.get_node_or_null("PuzzlePresentation")
			if presentation == null:
				presentation = script.new()
				room.add_child(presentation)
				presentation.setup(room)
			check(presentation.find_children("*", "CollisionObject3D", true, false).is_empty(), "presentation adds no physics")
			var snapshot: Dictionary = room.capture_state()
			for device in room.objects.values():
				if not device.has_method("satisfied"): continue
				if device.spec.kind == "plate":
					plate_count += 1
					var frame = presentation.plates[device.object_id]
					var floor_top := .09 if room.spec.get("belt", false) else 0.0
					check(frame.position.y > floor_top, device.object_id + " visible above floor / conveyor")
					var idle_y: float = frame.get_node("Deck").position.y
					room.objects.crate.position = Vector3(device.position.x,.03,0)
					presentation.update(0)
					check(frame.get_node("Deck").position.y < idle_y and frame.get_meta("active"), "plate depresses under crate")
					room.restore_state(snapshot)
					presentation.update(0)
					check(not frame.get_meta("active") and is_equal_approx(frame.get_node("Deck").position.y,idle_y), "plate restores unpressed")
				else:
					var visual = device.get_node("DeviceVisual")
					check(visual.get_meta("asset") == presentation.asset_for(device), device.object_id + " uses semantic model")
					check(is_instance_valid(device.lamp), "control lamp preserved")
					if device.object_id == "bell": check(visual.find_child("Bell",true,false) != null, "bell has actual bell assembly")
					if device.spec.kind == "brake": check(visual.get_meta("asset") == "props/brake", "brake has dedicated brake model")
					if device.spec.kind == "socket" and device.spec.accept == "fuse":
						check(visual.get_meta("asset") == "props/fuse_box" and not visual.find_child("Fuse",true,false).visible, "fuse cabinet visibly empty")
					if device.spec.kind in ["latch","brake"]:
						device.state = 1
						device.timer = 12
						presentation.update(0)
						check(device.get_node("StateIndicator").material_override.albedo_color == presentation.ACTIVE, "control indicates active state")
						room.restore_state(snapshot)
						presentation.update(0)
						check(device.get_node("StateIndicator").material_override.albedo_color == presentation.BRASS, "control indicator restores")
			room.completed = true
			presentation.update(0)
			check(presentation.exit_path.visible and presentation.exit_light.light_energy > 0, "completion lights exit path")
			room.restore_state(snapshot)
			presentation.update(0)
			check(not presentation.exit_path.visible and presentation.exit_light.light_energy == 0, "restore clears exit light")
			room.free()
	check(plate_count == 2, "both authored pressure plates checked; raft uses buoyancy")
	quit(1 if failures else 0)

extends SceneTree
var failures := 0
func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var content = load("res://scripts/puzzles/campaign_content.gd")
	for index in [0, 1, 2, 4]:
		var room = load("res://scripts/puzzles/puzzle_room.gd").new()
		room.spec = content.rooms("laundry")[index]
		room.theme = "laundry"
		room.index = index
		root.add_child(room)
		room.set_physics_process(false)
		var basin = room.water
		check(basin.has_method("set_water_level"), "room %d has a complete basin" % (index + 1))
		if not basin.has_method("set_water_level"):
			room.free()
			continue
		for level in [.1, .8, 1.9, .45]:
			basin.set_water_level(level)
			var body: MeshInstance3D = basin.get_node("Volume")
			var bounds: AABB = body.transform * body.mesh.get_aabb()
			check(is_equal_approx(bounds.position.y, .005), "water bottom stays on basin floor")
			check(is_equal_approx(bounds.end.y, level + .04), "volume reaches surface while filling and draining")
			check(is_equal_approx(basin.get_node("Surface").position.y, bounds.end.y), "surface and volume have no gap")
			var snapshot: Dictionary = room.capture_state()
			basin.set_water_level(1.9)
			room.restore_state(snapshot)
			check(is_equal_approx(basin.water_level, level), "checkpoint restores intermediate water level")
		basin.set_water_level(-.05)
		check(not basin.get_node("Volume").visible and not basin.get_node("Surface").visible, "drained water leaves no floating sheet")
		for wall in basin.find_children("*", "StaticBody3D", true, false):
			var shape: CollisionShape3D = wall.get_node("CollisionShape3D")
			var size: Vector3 = shape.shape.size
			check(absf(wall.position.z) - size.z * .5 >= 1.9, "basin wall leaves player and cargo lane clear")
		room.free()
	quit(1 if failures else 0)

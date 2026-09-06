extends SceneTree
const ASSETS = ["drain", "fill", "winch_a", "winch_b", "bell", "brake", "wind", "release", "fuse_box", "power_switch", "laundry_cart", "spool_carrier", "pressure_plate", "steam_pipe", "last_bell", "exit_workshop", "exit_laundry", "exit_vault", "exit_clocktower"]
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/props")
	for id in ASSETS:
		var path: String = "res://assets/models/props/" + id + ".glb"
		if not ResourceLoader.exists(path):
			push_error("Missing mechanical asset: " + path)
			quit(1)
			return
	for id in ASSETS:
		var visual := Node3D.new()
		visual.name = id.to_pascal_case()
		visual.set_script(load("res://scripts/props/prop_visual.gd"))
		visual.set("kind", id)
		var model = load("res://assets/models/props/" + id + ".glb").instantiate()
		model.name = "Model"
		visual.add_child(model)
		model.owner = visual
		var packed := PackedScene.new()
		if packed.pack(visual) != OK or ResourceSaver.save(packed, "res://scenes/props/" + id + ".tscn") != OK:
			push_error("Failed to pack " + id)
			quit(1)
			return
		visual.free()
	print("BUILT 19 MECHANICAL PROP SCENES")
	quit()

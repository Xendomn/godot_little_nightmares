extends SceneTree

var scene_root: Node3D
var world: Node3D
var materials: Dictionary = {}

func _initialize() -> void:
	call_deferred("build")

func mat(key: String, color: String, metallic: float = 0.0) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color)
	result.roughness = 0.84
	result.metallic = metallic
	materials[key] = result
	return result

func box(parent: Node, title: String, pos: Vector3, size: Vector3, material: Material, solid: bool = false) -> Node3D:
	var result: Node3D = StaticBody3D.new() if solid else Node3D.new()
	result.name = title
	result.position = pos
	parent.add_child(result)
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	result.add_child(mesh)
	if solid:
		var collider := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = size
		collider.shape = collision
		result.add_child(collider)
	return result

func cylinder(parent: Node, title: String, pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	mesh.position = pos
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 16
	mesh.mesh = shape
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

func light(parent: Node, title: String, pos: Vector3, color: String, energy: float, radius: float, shadows: bool = false) -> OmniLight3D:
	var result := OmniLight3D.new()
	result.name = title
	result.position = pos
	result.light_color = Color(color)
	result.light_energy = energy
	result.omni_range = radius
	result.shadow_enabled = shadows
	parent.add_child(result)
	return result

func model(parent: Node, filename: String, title: String, pos: Vector3, scale_value: float = 1) -> Node3D:
	var path := "res://assets/models/" + filename + ".glb"
	var result: Node3D
	if ResourceLoader.exists(path):
		result = load(path).instantiate()
	else:
		result = Node3D.new()
		box(result, "Placeholder", Vector3(0, 0.5, 0), Vector3(0.6, 1, 0.5), mat("teal", "397f83"))
	result.name = title
	result.position = pos
	result.scale = Vector3.ONE * scale_value
	parent.add_child(result)
	return result

func text3d(parent: Node, title: String, words: String, pos: Vector3, font_size: int = 80, color: String = "ac9f82") -> Label3D:
	var text := Label3D.new()
	text.name = title
	text.text = words
	text.position = pos
	text.font_size = font_size
	text.pixel_size = 0.008
	text.modulate = Color(color)
	text.outline_size = 0
	parent.add_child(text)
	return text

func build() -> void:
	seed(9326)
	scene_root = Node3D.new()
	scene_root.name = "MidnightWorkshop"
	scene_root.set_script(load("res://scripts/game.gd"))
	world = Node3D.new()
	world.name = "World"
	scene_root.add_child(world)
	var wood := mat("wood", "574535")
	var wood_dark := mat("wood_dark", "302c27")
	var iron := mat("iron", "28383e", 0.6)
	var brass := mat("brass", "ae8252", 0.5)
	var plaster := mat("plaster", "37454b")
	var red := mat("red", "814c40")
	var teal := mat("teal", "397f83")
	var cream := mat("cream", "bcb098")
	var belt_material := ShaderMaterial.new()
	belt_material.shader = load("res://assets/shaders/conveyor.gdshader")
	# Ground is split at the three conveyor gaps; each gap spans the full lane.
	for span in [[-3.0, 61.8], [63.25, 69.8], [71.25, 77.8], [79.25, 94.0]]:
		var x: float = (span[0] + span[1]) * 0.5
		var width: float = span[1] - span[0]
		box(world, "Floor", Vector3(x, -0.4, 0), Vector3(width, 0.8, 6), wood_dark if x < 54 else iron, true)
		for plank in range(int(span[0] * 2) + 1, int(span[1] * 2)):
			var board = box(world, "FloorBoard", Vector3(plank * 0.5, 0.005, 0), Vector3(0.47, 0.035, 5.7), wood if plank * 0.5 < 54 else belt_material)
			if plank * 0.5 >= 54:
				board.get_child(0).add_to_group("conveyor_surfaces", true)
	box(world, "BackWall", Vector3(44, 4, -3.4), Vector3(98, 8, 0.5), plaster, true)
	box(world, "StartingWall", Vector3(-2.7, 2, 0), Vector3(0.6, 4, 6), wood_dark, true)
	for x in range(-2, 95, 6):
		box(world, "WallPillar", Vector3(x, 3.8, -3.0), Vector3(0.25, 7.6, 0.35), wood_dark)
		box(world, "WallPanel", Vector3(x + 2.9, 1.4, -3.08), Vector3(5.7, 2.5, 0.15), wood_dark)
		box(world, "PanelInset", Vector3(x + 2.9, 1.5, -2.96), Vector3(5.25, 1.8, 0.04), plaster)
		for y in [0.3, 2.6, 6.8]:
			box(world, "Rail", Vector3(x + 2.9, y, -2.85), Vector3(5.8, 0.12, 0.18), iron)
		# Dusty high windows, with strips of cold reflected light.
		box(world, "WindowFrame", Vector3(x + 2.8, 5.2, -3.0), Vector3(3.3, 2.1, 0.25), iron)
		var glass := mat("glass", "668a91")
		glass.emission_enabled = true
		glass.emission = Color("486b78")
		glass.emission_energy_multiplier = 0.45
		box(world, "WindowGlass", Vector3(x + 2.8, 5.2, -2.83), Vector3(3.05, 1.9, 0.03), glass)
		box(world, "WindowMullion", Vector3(x + 2.8, 5.2, -2.77), Vector3(0.1, 1.9, 0.08), iron)
		box(world, "WindowCross", Vector3(x + 2.8, 5.2, -2.77), Vector3(3.1, 0.1, 0.08), iron)
		light(world, "WindowGlow", Vector3(x + 2.8, 4.5, -1.7), "83b6c3", 0.8, 7)
	# Ceiling pipes and suspended brass lamps repeat at human-scale intervals.
	for x in range(4, 93, 9):
		cylinder(world, "LampCable", Vector3(x, 6.5, 0), 0.035, 3, iron)
		var shade := cylinder(world, "LampShade", Vector3(x, 5.0, 0), 0.48, 0.28, brass)
		shade.rotation.z = 0.06
		light(world, "Pendant", Vector3(x, 4.7, 0.2), "ffd095", 1.8, 7.5, true)
	for z in [-2.5, -2.1]:
		var pipe := cylinder(world, "LongPipe", Vector3(44, 7, z), 0.12, 97, iron)
		pipe.rotation.z = PI / 2
	# First room: giant workbench, scattered toys and a single movable step.
	box(world, "WorkbenchTop", Vector3(13, 1.86, -0.25), Vector3(5.2, 0.32, 3.4), wood, true)
	for x in [10.65, 15.35]:
		for z in [-1.55, 1.05]:
			box(world, "WorkbenchLeg", Vector3(x, 0.85, z), Vector3(0.3, 1.7, 0.3), wood_dark, true)
	box(world, "BenchApron", Vector3(13, 1.55, -1.5), Vector3(4.7, 0.4, 0.18), wood_dark)
	for x in [11.2, 12.4, 13.6, 14.8]:
		box(world, "BenchDrawer", Vector3(x, 1.55, 1.39), Vector3(1.12, 0.33, 0.1), wood_dark)
		box(world, "DrawerPull", Vector3(x, 1.55, 1.48), Vector3(0.27, 0.05, 0.07), brass)
	model(world, "spool", "BenchSpool", Vector3(14.4, 2.03, -1.05), 1.6)
	model(world, "toy_train", "ForgottenTrain", Vector3(4.2, 0.03, -1.7), 1.2)
	model(world, "spool", "FloorSpool", Vector3(17, 0.03, -1.2), 1.3)
	for i in range(9):
		var block = box(world, "AlphabetBlock", Vector3(randf_range(1, 19), 0.15, randf_range(1.95, 2.6)), Vector3(0.3, 0.3, 0.3), [red, teal, cream][i % 3])
		block.rotation.y = randf() * 3
	var crate := CharacterBody3D.new()
	crate.name = "PushCrate"
	crate.position = Vector3(6.0, 0.03, 0)
	crate.set_script(load("res://scripts/push_crate.gd"))
	world.add_child(crate)
	model(crate, "crate", "Model", Vector3.ZERO)
	var crate_shape := CollisionShape3D.new()
	crate_shape.name = "CollisionShape3D"
	var crate_box := BoxShape3D.new()
	crate_box.size = Vector3(0.95, 1.05, 0.95)
	crate_shape.shape = crate_box
	crate_shape.position.y = 0.525
	crate.add_child(crate_shape)
	interactable("fuse", Vector3(12.8, 2.1, 0.25))
	light(world, "FuseGlow", Vector3(12.8, 2.5, 0.25), "6af9d2", 1.2, 2.5)
	text3d(world, "WorkshopName", "NO. 07\nMIDNIGHT TOY WORKS", Vector3(12.8, 4.2, -2.65), 57)
	# Low ducts intentionally require crouching; standing clearance is 0.87.
	box(world, "LowDuct", Vector3(21.5, 1.65, 0), Vector3(3.2, 1.5, 4.3), iron, true)
	for x in [20, 21, 22, 23]:
		box(world, "DuctBand", Vector3(x, 2.45, 0), Vector3(0.07, 0.05, 4.4), brass)
	gate("FuseGate", 23.75, iron)
	# Second room. Tables can be crawled under; keeper patrols the clear back aisle.
	text3d(world, "AssemblySign", "02   /   ASSEMBLY", Vector3(37, 4.05, -2.65), 80)
	for x in [36.5, 43]:
		box(world, "AssemblyTable", Vector3(x, 1.1, 0.7), Vector3(3.2, 0.28, 2.0), wood, true)
		for dx in [-1.4, 1.4]:
			for z in [-0.15, 1.55]:
				box(world, "TableLeg", Vector3(x + dx, 0.45, z), Vector3(0.16, 0.9, 0.16), iron, true)
		model(world, "toy_train", "UnfinishedToy", Vector3(x, 1.25, 0.3), 1)
		model(world, "spool", "Thread", Vector3(x + 1, 1.25, 1), 0.8)
	for x in [27, 40, 48]:
		box(world, "ToolCabinet", Vector3(x, 1.5, -2.25), Vector3(2, 3, 1.0), wood_dark, true)
		for y in [0.4, 1.1, 1.8, 2.5]:
			box(world, "CabinetDrawer", Vector3(x, y, -1.71), Vector3(1.85, 0.57, 0.08), wood)
			box(world, "CabinetHandle", Vector3(x, y, -1.6), Vector3(0.34, 0.06, 0.13), brass)
	box(world, "PanelHousing", Vector3(30.7, 0.8, -0.9), Vector3(0.85, 1.6, 0.5), iron, true)
	interactable("panel", Vector3(30.7, 0.9, -0.52))
	light(world, "PanelLamp", Vector3(30.7, 1.4, -0.4), "db6943", 0.8, 2)
	text3d(world, "PanelSign", "FUSE", Vector3(30.7, 1.2, -0.59), 28)
	# Painted conduit visually connects fuse box to the far switch.
	box(world, "PowerConduit", Vector3(41, 2.9, -2.7), Vector3(20.5, 0.06, 0.06), brass)
	box(world, "LeverHousing", Vector3(51, 0.8, -0.9), Vector3(0.65, 1.6, 0.5), iron, true)
	var handle = box(world, "SwitchHandle", Vector3(51, 1.25, -0.53), Vector3(0.12, 0.65, 0.14), red)
	handle.rotation.z = -0.4
	interactable("lever", Vector3(51, 1.0, -0.4))
	text3d(world, "SwitchSign", "POWER", Vector3(51, 1.65, -0.55), 25)
	gate("PowerGate", 53.65, iron)
	# Conveyor: edge lips, rollers, striped warnings, exit chute.
	text3d(world, "DispatchSign", "03   /   DISPATCH", Vector3(62, 4.0, -2.65), 80)
	for x in range(55, 87):
		for z in [-2.25, 2.25]:
			box(world, "BeltRail", Vector3(x, 0.22, z), Vector3(0.96, 0.3, 0.14), iron)
		if x % 2 == 0:
			var roller := cylinder(world, "Roller", Vector3(x, -0.2, 0), 0.15, 4.2, brass)
			roller.rotation.x = PI / 2
	for x in [61.3, 69.3, 77.3]:
		box(world, "JumpWarning", Vector3(x, 0.04, 0), Vector3(0.3, 0.03, 4.3), brass)
		text3d(world, "JumpMark", "!", Vector3(x, 0.65, -2.5), 70, "d9ad6f")
	box(world, "ConveyorLowPassage", Vector3(74.0, 1.6, 0), Vector3(2.0, 1.4, 4.3), iron, true)
	text3d(world, "DuckSign", "↓", Vector3(73.1, 1.8, 2.18), 95, "d9ad6f")
	box(world, "ExitFrame", Vector3(88.5, 2, -1.6), Vector3(4.4, 4, 1.2), iron)
	box(world, "ExitOpening", Vector3(87.9, 1.3, -0.95), Vector3(2.7, 2.5, 0.05), mat("exit_black", "081719"))
	text3d(world, "ExitSign", "OUTSIDE  →", Vector3(85.5, 3.5, -2.65), 76, "a8d9c5")
	light(world, "ExitLamp", Vector3(86, 2.6, -0.3), "9de8cf", 0.2, 7)
	# Foreground silhouettes frame the tiny character without covering the lane.
	for x in [0, 18, 29, 46, 58, 82]:
		model(world, "spool", "ForegroundSpool", Vector3(x, -0.02, 3.1), 1.7)
		box(world, "ForegroundCrate", Vector3(x + 1.1, 0.3, 3.2), Vector3(0.85, 0.6, 0.7), wood_dark)
	# Oversized wall clocks and faded shipping notices add a workshop identity.
	for x in [6.5, 33.5, 47.5, 80.5]:
		var clock_face := cylinder(world, "ClockFace", Vector3(x, 3.6, -2.78), 0.64, 0.12, brass)
		clock_face.rotation.x = PI / 2
		var inset := cylinder(world, "ClockInset", Vector3(x, 3.6, -2.69), 0.57, 0.02, cream)
		inset.rotation.x = PI / 2
		box(world, "ClockHand", Vector3(x, 3.81, -2.66), Vector3(0.04, 0.43, 0.02), iron)
		var hand = box(world, "ClockHandSmall", Vector3(x + 0.12, 3.65, -2.64), Vector3(0.28, 0.05, 0.02), iron)
		hand.rotation.z = 0.4
	for x in [17.5, 26, 45, 66]:
		box(world, "FadedNotice", Vector3(x, 3.1, -2.79), Vector3(1.25, 1.7, 0.025), mat("paper", "7f806e"))
		text3d(world, "NoticePrint", "HANDLE\nWITH\nCARE", Vector3(x, 3.2, -2.75), 29, "293c3d")
	# Paper offcuts lie flat outside the walkable depth, avoiding visual obstruction.
	for i in range(28):
		var paper = box(world, "PaperOffcut", Vector3(randf_range(0, 88), 0.035, randf_range(1.9, 2.7)), Vector3(randf_range(0.12, 0.4), 0.004, 0.24), cream)
		paper.rotation.y = randf_range(-PI, PI)
	create_actors()
	create_environment()
	apply_patina(scene_root)
	assign_owner(scene_root)
	var scene := PackedScene.new()
	var error := scene.pack(scene_root)
	if error == OK:
		DirAccess.make_dir_recursive_absolute("res://scenes")
		error = ResourceSaver.save(scene, "res://scenes/main.tscn")
	print("SCENE_BUILD: ", error, " nodes=", scene_root.find_children("*", "", true, false).size())
	scene_root.free()
	quit(error)

func gate(title: String, x: float, material: Material) -> void:
	var gate_body := StaticBody3D.new()
	gate_body.name = title
	gate_body.position = Vector3(x, 0, 0)
	world.add_child(gate_body)
	for z in [-2.0, -1.4, -0.8, -0.2, 0.4, 1.0, 1.6, 2.2]:
		box(gate_body, "Bar", Vector3(0, 1.5, z), Vector3(0.15, 3, 0.1), material)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 3.0, 4.8)
	collision.shape = shape
	collision.position.y = 1.5
	gate_body.add_child(collision)

func interactable(kind: String, pos: Vector3) -> void:
	var node := Node3D.new()
	node.name = kind.capitalize()
	node.position = pos
	node.set_script(load("res://scripts/interactable.gd"))
	node.kind = kind
	node.add_to_group("interactables", true)
	world.add_child(node)
	if kind == "fuse":
		model(node, "fuse", "Model", Vector3(0, 0.12, 0), 1.6)

func create_actors() -> void:
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(2, 0.05, 0)
	player.collision_layer = 2
	player.collision_mask = 1
	player.set_script(load("res://scripts/player.gd"))
	scene_root.add_child(player)
	model(player, "doll", "Visual", Vector3.ZERO)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.2
	shape.shape = capsule
	shape.position.y = 0.62
	player.add_child(shape)
	light(player, "SoftRim", Vector3(0, 1.2, 0.6), "80cbd1", 0.45, 2.2)
	var keeper := CharacterBody3D.new()
	keeper.name = "Keeper"
	keeper.position = Vector3(46, 0.05, -1.3)
	keeper.collision_layer = 4
	keeper.collision_mask = 1
	keeper.set_script(load("res://scripts/keeper.gd"))
	scene_root.add_child(keeper)
	model(keeper, "keeper", "Visual", Vector3.ZERO)
	var keeper_shape := CollisionShape3D.new()
	keeper_shape.name = "CollisionShape3D"
	var keeper_capsule := CapsuleShape3D.new()
	keeper_capsule.radius = 0.32
	keeper_capsule.height = 3.4
	keeper_shape.shape = keeper_capsule
	keeper_shape.position.y = 1.7
	keeper.add_child(keeper_shape)
	light(keeper, "EyeLight", Vector3(0.25, 2.8, 0.3), "ffb45e", 0.7, 3)
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(6, 4.8, 11.8)
	camera.fov = 52
	camera.current = true
	camera.set_script(load("res://scripts/cinematic_camera.gd"))
	scene_root.add_child(camera)
	var ui := CanvasLayer.new()
	ui.name = "Interface"
	ui.set_script(load("res://scripts/interface.gd"))
	scene_root.add_child(ui)
	var audio := Node.new()
	audio.name = "Soundscape"
	audio.set_script(load("res://scripts/soundscape.gd"))
	scene_root.add_child(audio)

func create_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "Atmosphere"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1c2d35")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("7b9caa")
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("425a64")
	env.fog_density = 0.009
	env.fog_sky_affect = 0.3
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.6
	we.environment = env
	scene_root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Moonlight"
	sun.rotation_degrees = Vector3(-45, -25, -15)
	sun.light_color = Color("7b9cba")
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	scene_root.add_child(sun)

func assign_owner(node: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		if child.scene_file_path.is_empty():
			assign_owner(child)

func apply_patina(node: Node) -> void:
	for child in node.get_children():
		if not child.scene_file_path.is_empty():
			continue
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			var old: StandardMaterial3D = child.material_override
			if not old.emission_enabled:
				var material := ShaderMaterial.new()
				material.shader = load("res://assets/shaders/patina.gdshader")
				material.set_shader_parameter("base_color", old.albedo_color)
				material.set_shader_parameter("metal", old.metallic)
				material.set_shader_parameter("grain", 1.0 if old == materials["wood"] or old == materials["wood_dark"] else 0.0)
				child.material_override = material
		apply_patina(child)

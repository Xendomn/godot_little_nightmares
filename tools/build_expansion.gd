extends "res://tools/build_scene.gd"
## Offline authoring tool. All geometry is saved as editable scene nodes.

const IDS := ["workshop", "laundry", "thread_vault", "clocktower"]
const TITLES := ["午夜工坊", "染洗间", "悬线库", "钟楼"]
var iron: Material
var brass: Material
var cloth: Material
var stone: Material
var build_failed := false

func build() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/chapters")
	DirAccess.make_dir_recursive_absolute("res://scenes/actors")
	DirAccess.make_dir_recursive_absolute("res://resources/levels")
	if not FileAccess.file_exists("res://scenes/chapters/workshop.tscn"):
		push_error("Missing workshop.tscn: run tools/build_scene.gd before build_expansion.gd.")
		quit(1)
		return
	if not mechanical_props_ready():
		quit(1)
		return
	# Reusable actor scenes retain GLB instance ownership and imported rigs.
	scene_root = Node3D.new()
	create_actors()
	for actor in scene_root.get_children():
		var packed := PackedScene.new()
		own_actor(actor, actor)
		if packed.pack(actor) != OK or ResourceSaver.save(packed, "res://scenes/actors/" + actor.name.to_lower() + ".tscn") != OK:
			push_error("Failed to save actor: " + actor.name)
			quit(1)
			return
	scene_root.free()
	for index in range(4):
		var definition = load("res://scripts/campaign/level_definition.gd").new()
		definition.id = IDS[index]
		definition.title = TITLES[index]
		definition.scene_path = "res://scenes/chapters/" + IDS[index] + ".tscn"
		definition.next_id = IDS[index + 1] if index < 3 else ""
		definition.camera_max = 64 if index == 3 else (56 if index > 0 else 84)
		var spawns := [[Vector3(2, .05, 0), Vector3(25, .05, 0), Vector3(55, .05, 0)], [Vector3(2, .05, 0), Vector3(18, .05, 0), Vector3(31, 2.65, 1.1)], [Vector3(2, .05, 0), Vector3(18, .05, 0), Vector3(40, .05, 1.1)], [Vector3(2, .05, 0), Vector3(18, .05, 0), Vector3(35, 2.65, 0)]]
		definition.checkpoint_positions.assign(spawns[index])
		if ResourceSaver.save(definition, "res://resources/levels/" + IDS[index] + ".tres") != OK:
			push_error("Failed to save level definition")
			quit(1)
			return
		if index > 0:
			build_chapter(index)
			if build_failed:
				quit(1)
				return
	var main := Node.new()
	main.name = "Campaign"
	main.set_script(load("res://scripts/campaign/campaign.gd"))
	var packed := PackedScene.new()
	if packed.pack(main) != OK or ResourceSaver.save(packed, "res://scenes/main.tscn") != OK:
		push_error("Failed to save campaign scene")
		quit(1)
		return
	main.free()
	print("BUILT FOUR CHAPTER CAMPAIGN")
	quit()

func own_actor(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		if child.scene_file_path.is_empty():
			own_actor(child, owner_node)

func build_chapter(index: int) -> void:
	seed(2609 + index)
	scene_root = Node3D.new()
	scene_root.name = IDS[index].to_pascal_case()
	scene_root.set_script(load("res://scripts/chapters/chapter.gd"))
	scene_root.set("level_id", IDS[index])
	world = Node3D.new()
	world.name = "World"
	scene_root.add_child(world)
	iron = mat("iron", "293940", .7)
	brass = mat("brass", "b28b53", .55)
	cloth = mat("cloth", "7f8880")
	stone = mat("stone", "3e5558")
	mat("wood", "574535")
	mat("wood_dark", "302c27")
	for name in ["player", "keeper", "camera", "interface", "soundscape"]:
		scene_root.add_child(load("res://scenes/actors/" + name + ".tscn").instantiate())
	scene_root.get_node("Soundscape").set("ambience_name", IDS[index] + "_ambient")
	create_environment()
	scene_root.get_node("Atmosphere").environment.fog_density = .012
	var length := 75 if index == 3 else 66
	box(world, "BackWall", Vector3(length * .5, 5, -3.3), Vector3(length + 6, 10, .5), stone)
	box(world, "StartWall", Vector3(-2, 2, 0), Vector3(.5, 4, 6), iron, true)
	for x in range(0, length, 6):
		box(world, "Rib", Vector3(x, 4.5, -2.9), Vector3(.22, 9, .24), iron)
		box(world, "WallInset", Vector3(x + 3, 3.8, -2.98), Vector3(5.5, 6.8, .08), mat("inset", "24383d"))
		light(world, "ColdReflection", Vector3(x + 3, 5, -2), "79a5b8", .8, 8)
		if x % 12 == 0:
			cylinder(world, "Cable", Vector3(x + 2, 7, 0), .025, 4, iron)
			cylinder(world, "Shade", Vector3(x + 2, 5, 0), .4, .2, brass)
			light(world, "WorkLamp", Vector3(x + 2, 4.7, .5), "ffd2a0", 1.7, 8, true)
	text3d(world, "Title", ["", "02 / THE RINSE HOUSE", "03 / THREAD VAULT", "04 / THE LAST BELL"][index], Vector3(7, 4.1, -2.7), 64)
	match index:
		1: laundry()
		2: vault()
		3: clocktower()
	var exit_x := 70 if index == 3 else 63
	prop(world, "exit_" + ("vault" if index == 2 else IDS[index]), "ExitVisual", Vector3(exit_x, 2.6 if index != 2 else 0, -1))
	var glow := mat("dawn" + str(index), "e6dbc1")
	glow.emission_enabled = true
	glow.emission = Color("ffe7b9")
	glow.emission_energy_multiplier = 1.2
	# Recessed light beyond the modeled opening, never a flat front door.
	box(world, "ExitGlow", Vector3(exit_x, 2.2 + (2.6 if index != 2 else 0), -2.6), Vector3(2.2, 3.9, .05), glow)
	light(world, "ExitLight", Vector3(exit_x, 3 + (2.6 if index != 2 else 0), .2), "ffe0ad", 3, 7)
	apply_patina(scene_root)
	load("res://tools/keeper_navigation_mesh.gd").attach(scene_root, IDS[index])
	assign_owner(scene_root)
	var packed := PackedScene.new()
	var error := packed.pack(scene_root)
	if error == OK:
		error = ResourceSaver.save(packed, "res://scenes/chapters/" + IDS[index] + ".tscn")
	print(IDS[index], " scene saved: ", error)
	if error != OK:
		push_error("Failed to save chapter " + IDS[index])
		build_failed = true
	scene_root.free()

func floor_span(a: float, b: float, y: float = 0) -> void:
	box(world, "Floor", Vector3((a + b) / 2, y - .3, 0), Vector3(b - a, .6, 5.8), iron, true)
	for x in range(int(a * 2) + 1, int(b * 2)):
		box(world, "FloorSeam", Vector3(x * .5, y + .007, 0), Vector3(.025, .015, 5.5), brass)

func mechanism(id: String, pos: Vector3, words: String) -> void:
	var item := Node3D.new()
	item.name = id.to_pascal_case()
	item.position = pos
	item.set_script(load("res://scripts/chapters/mechanism.gd"))
	item.set("id", id)
	item.set("prompt", words)
	world.add_child(item)
	var floor_y := 2.6 if id == "release" else 0.0
	prop(item, id, "Visual", Vector3(0, floor_y - pos.y, 0))
	light(item, "Signal", Vector3(0, .15, .25), "e4c390", .4, 1.8)

func platform(title: String, pos: Vector3, size: Vector3, travel: Vector3) -> void:
	var body := AnimatableBody3D.new()
	body.name = title
	body.position = pos
	body.set_script(load("res://scripts/chapters/moving_platform.gd"))
	body.set("travel", travel)
	world.add_child(body)
	box(body, "Deck", Vector3(0, -.16, 0), size, brass)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = -.16
	body.add_child(collision)
	for z in [-1.7, 1.7]:
		cylinder(world, "LiftRail", Vector3(pos.x, 2, z), .07, 5, iron)

func push_box(x: float, destination: float, label: String) -> void:
	var crate := CharacterBody3D.new()
	crate.name = "PushCrate"
	crate.position = Vector3(x, .03, 0)
	crate.set_script(load("res://scripts/push_crate.gd"))
	crate.set("min_x", x - 1)
	crate.set("max_x", destination)
	crate.set("display_name", label)
	world.add_child(crate)
	prop(crate, "laundry_cart" if label == "洗衣车" else "spool_carrier", "Model", Vector3.ZERO)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.95, 1.05, .95)
	collider.shape = shape
	collider.position.y = .525
	crate.add_child(collider)
	prop(world, "pressure_plate", "PressurePlate", Vector3(destination, 0, 0))

func hazard(title: String, x: float, y: float, width: float = 1, period: float = 5, duration: float = 2) -> void:
	var area := Area3D.new()
	area.name = title
	area.position = Vector3(x, y, 0)
	area.collision_mask = 2
	area.collision_layer = 0
	area.set_script(load("res://scripts/chapters/hazard.gd"))
	area.set("period", period)
	area.set("active_duration", duration)
	area.set("caption", "STEAM" if title.begins_with("Steam") else "SWING")
	world.add_child(area)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 1.8, 3.8)
	collider.shape = shape
	collider.position.y = .9
	area.add_child(collider)
	if title.begins_with("Steam"):
		var mist := MeshInstance3D.new()
		mist.name = "Warning"
		mist.position.y = 1.2
		var mesh := QuadMesh.new()
		mesh.size = Vector2(width * 1.5, 2.6)
		mist.mesh = mesh
		var shader := ShaderMaterial.new()
		shader.shader = load("res://assets/shaders/steam.gdshader")
		mist.material_override = shader
		area.add_child(mist)
		var leak := mist.duplicate() as MeshInstance3D
		leak.name = "PreLeak"
		leak.position = Vector3(0, .75, -1.65)
		leak.scale = Vector3(.25, .35, 1)
		leak.visible = false
		area.add_child(leak)
	else:
		box(area, "Warning", Vector3(0, .035, 0), Vector3(width, .04, 3.5), mat("warning", "bd603d"))
	if title.begins_with("Steam"):
		prop(area, "steam_pipe", "Visual", Vector3(0, 0, -1.8))

func hide_table(x: float, y: float) -> void:
	box(world, "HidingTable", Vector3(x, y + 1.1, .7), Vector3(3.4, .28, 2), materials["wood"], true)
	for dx in [-1.55, 1.55]:
		for z in [-.15, 1.55]:
			box(world, "Leg", Vector3(x + dx, y + .45, z), Vector3(.16, .9, .16), iron, true)
	model(world, "spool", "Thread", Vector3(x, y + 1.25, .3), 1.3)

func laundry() -> void:
	floor_span(-3, 23)
	floor_span(27, 66, 2.6)
	mechanism("drain", Vector3(7, .7, -.65), "{interact}  转动排水阀")
	box(world, "Water", Vector3(13, .15, 0), Vector3(6, .28, 5.7), mat("water", "43747c", .5)).set_script(load("res://scripts/props/draining_water.gd"))
	# A continuous pipe ties the valve to the basin instead of naming its function.
	for x in [7.5, 8.5, 9.5]:
		var pipe := cylinder(world, "DrainConduit", Vector3(x, .22, -1.8), .09, 1.05, brass)
		pipe.rotation.z = PI / 2
		var sleeve := cylinder(world, "PipeUnion", Vector3(x + .47, .22, -1.8), .13, .13, iron)
		sleeve.rotation.z = PI / 2
	hazard("WaterHazard", 13, 0, 6, 1000, 1000)
	world.get_node("WaterHazard/Warning").visible = false
	push_box(21, 25, "洗衣车")
	platform("Lift", Vector3(25, 0, 0), Vector3(4, .32, 3.6), Vector3(0, 2.6, 0))
	mechanism("fill", Vector3(24.4, .85, -1.2), "{interact}  打开灌水杆 · 先把洗衣车推上黄框")
	# Lift control travels with platform, remaining accessible after activation.
	for x in [3, 11, 18, 34, 44, 57]:
		var drum := cylinder(world, "WashingDrum", Vector3(x, 2 + (2.6 if x > 27 else 0), -2.5), 1.7, 1, iron)
		drum.rotation.x = PI / 2
		var rim := cylinder(world, "DrumRim", drum.position + Vector3(0, 0, .55), 1.25, .1, brass)
		rim.rotation.x = PI / 2
		for i in range(8):
			var angle := i * TAU / 8
			box(world, "DrumBolt", rim.position + Vector3(cos(angle) * 1.05, sin(angle) * 1.05, .12), Vector3(.11, .11, .11), iron)
	for x in [37, 44]:
		hide_table(x, 2.6)
		box(world, "HangingSheet", Vector3(x, 5.9, -1.85), Vector3(3, 3, .06), cloth, true)
	for x in [52, 55]:
		hazard("Steam" + str(x), x, 2.6, .85, 5.5, 1.8)
		world.get_node("Steam" + str(x)).set("phase_offset", 1.5 if x == 55 else 0)

func vault() -> void:
	for span in [[-3, 12], [16, 24], [28, 34], [38, 66]]:
		floor_span(span[0], span[1])
	push_box(6, 10, "线轴箱")
	for i in range(3):
		platform("Bridge" + str(i), Vector3([14, 26, 36][i], 3.4, 0), Vector3(4.1, .32, 3.6), Vector3(0, -3.4, 0))
	mechanism("winch_a", Vector3(21, .75, -.7), "{interact}  转动第一绞盘")
	mechanism("winch_b", Vector3(31, .75, -.7), "{interact}  转动第二绞盘")
	mechanism("bell", Vector3(41, .75, .9), "{interact}  摇铃引开守卫 · 可重复使用")
	for x in range(2, 64, 5):
		for y in [1.5, 3.5, 5.5]:
			box(world, "RackShelf", Vector3(x, y - .2, -2.4), Vector3(4, .13, 1), materials["wood"])
			for dx in [-1.2, 0, 1.2]:
				model(world, "spool", "StoredSpool", Vector3(x + dx, y, -2.4), 1.6)
		for dx in [-1.9, 1.9]:
			box(world, "RackUpright", Vector3(x + dx, 3.2, -2.4), Vector3(.14, 6.4, .14), iron)
	for x in [46, 52.5]:
		hide_table(x, 0)
	for i in range(3):
		var x: float = [14, 26, 36][i]
		for z in [-1.65, 1.65]:
			var rope := cylinder(world, "SuspensionThread", Vector3(x, 5, z), .025, 1, cloth)
			rope.set_script(load("res://scripts/props/suspension_cable.gd"))
			rope.set("target_path", NodePath("../Bridge" + str(i)))
			rope.set("attachment", Vector3(0, .05, z))

func clocktower() -> void:
	floor_span(-3, 23)
	platform("Lift", Vector3(25, 0, 0), Vector3(4, .32, 3.6), Vector3(0, 2.6, 0))
	for span in [[27, 43], [44.3, 51], [52.3, 59], [60.3, 75]]:
		floor_span(span[0], span[1], 2.6)
	# Maintenance ledge for the tall pursuer, separated from the player's jump lane.
	box(world, "KeeperLedge", Vector3(51, 2.3, -2), Vector3(48, .6, 1.8), iron, true)
	mechanism("brake", Vector3(7, .75, -.6), "{interact}  制动摆锤 · 暂停八秒")
	for x in [11, 14]:
		hazard("Pendulum" + str(x), x, 0, .8, 3.5, 2.3)
		var pivot := Node3D.new()
		pivot.name = "PendulumPivot"
		pivot.position = Vector3(0, 5, -.6)
		world.get_node("Pendulum" + str(x)).add_child(pivot)
		box(pivot, "Stem", Vector3(0, -2, 0), Vector3(.12, 4, .15), brass)
		var disk := cylinder(pivot, "Weight", Vector3(0, -4, 0), .65, .2, brass)
		disk.rotation.x = PI / 2
	mechanism("wind", Vector3(24, .8, -1.2), "{interact}  给升降台上弦")
	mechanism("release", Vector3(31.5, 3.35, -.65), "{interact}  释放钟锤")
	box(world, "LowTunnel", Vector3(56, 4.15, .5), Vector3(2.7, 1.3, 2.9), iron, true)
	for x in [54.7, 57.3]:
		box(world, "ClearanceBand", Vector3(x, 3.48, .5), Vector3(.12, .08, 2.9), brass)
	for x in [6, 21, 38, 50, 65]:
		var gear := cylinder(world, "ClockGear", Vector3(x, 5.8, -2.5), 2, .2, brass)
		gear.rotation.x = PI / 2
		for i in range(16):
			var angle := TAU * i / 16
			var tooth = box(world, "GearTooth", Vector3(x + cos(angle) * 2, 5.8 + sin(angle) * 2, -2.5), Vector3(.5, .3, .3), brass)
			tooth.rotation.z = angle
		var hand = box(world, "ClockHand", Vector3(x, 5.8, -2.25), Vector3(.12, 3.5, .12), iron)
		hand.rotation.z = .7
	prop(world, "last_bell", "LastBell", Vector3(31.5, 8.3, -1))

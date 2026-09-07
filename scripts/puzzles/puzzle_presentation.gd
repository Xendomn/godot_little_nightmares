extends Node3D
## Read-only presentation of room mechanisms. Never adds or moves collision.
var room: Node3D
var plates: Dictionary = {}
var controls: Array = []
var exit_path: Node3D
var exit_light: OmniLight3D
var exit_material: StandardMaterial3D
const BRASS := Color(.72,.47,.16)
const ACTIVE := Color(.25,.86,.69)

func setup(owner_room: Node3D) -> void:
	name = "PuzzlePresentation"
	room = owner_room
	for device in room.objects.values():
		if not device.has_method("satisfied"): continue
		if device.spec.kind == "plate":
			build_plate(device)
		else:
			build_control(device)
	build_exit()
	update(0)

func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = .65
	mat.roughness = .4
	mat.emission_enabled = glow > 0
	mat.emission = color
	mat.emission_energy_multiplier = glow
	return mat

func box(parent: Node3D, label: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	return node

func build_plate(device: Node3D) -> void:
	var frame := Node3D.new()
	frame.name = str(device.object_id) + "Frame"
	frame.position = Vector3(device.position.x,.12 if room.spec.get("belt",false) else .03,0)
	add_child(frame)
	plates[device.object_id] = frame
	var brass := material(BRASS, .22)
	for x in [-.89,.89]: box(frame,"Side",Vector3(x,0,0),Vector3(.09,.025,2.3),brass)
	for z in [-1.1,1.1]: box(frame,"End",Vector3(0,0,z),Vector3(1.85,.025,.09),brass)
	var deck := box(frame,"Deck",Vector3(0,.018,0),Vector3(1.68,.012,2.06),material(Color(.24,.21,.14)))
	for x in [-.62,-.31,0.0,.31,.62]:
		box(deck,"Grip",Vector3(x,.01,0),Vector3(.025,.01,1.82),brass)
	for x in [-.89,.89]:
		for z in [-.84,.84]: box(frame,"Contact",Vector3(x,.02,z),Vector3(.105,.012,.18),material(BRASS,.7))

func asset_for(device: Node3D) -> String:
	var id: String = device.object_id
	var kind: String = device.spec.kind
	if id == "bell": return "props/bell"
	if kind == "brake": return "props/brake"
	if kind == "socket":
		match str(device.spec.get("accept","")):
			"fuse": return "props/fuse_box"
			"weight": return "expansion/cargo_basket"
			"wheel": return "props/drain"
			"gear": return "expansion/clutch"
	if kind == "selector":
		if id == "power": return "props/power_switch"
		if id in ["inlet","transfer","pressure"]: return "props/fill"
		return "expansion/selector"
	if id == "drain" or "valve" in id or id in ["outlet","vent","seal","steam_lock"]: return "props/drain"
	if id == "fill": return "props/fill"
	return "props/release"

func build_control(device: Node3D) -> void:
	# Only remove authored model roots and the old floating symbol label.
	for child in device.get_children():
		if child is Label3D or (child is Node3D and not child is Light3D and not child is CollisionObject3D and child.scene_file_path.ends_with(".glb")):
			device.remove_child(child)
			child.free()
	var asset := asset_for(device)
	var visual: Node3D = load("res://assets/models/" + asset + ".glb").instantiate()
	visual.name = "DeviceVisual"
	visual.set_meta("asset",asset)
	device.add_child(visual)
	var bounds := AABB()
	var first := true
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		var local_bounds: AABB = (visual.global_transform.affine_inverse() * mesh.global_transform) * mesh.mesh.get_aabb()
		bounds = local_bounds if first else bounds.merge(local_bounds)
		first = false
	var factor := minf(1.35 / maxf(bounds.size.y,.01),1.15 / maxf(bounds.size.x,.01))
	factor = minf(factor,.85 / maxf(bounds.size.z,.01))
	visual.scale = Vector3.ONE * factor
	visual.position = Vector3(-bounds.get_center().x*factor,-.8-bounds.position.y*factor,-.15-bounds.get_center().z*factor)
	# Socket hosts must show an empty receiver; carried objects supply the part.
	if device.spec.kind == "socket":
		var removable: Node3D = visual.find_child("Fuse" if device.spec.accept == "fuse" else "Rotor",true,false)
		if removable: removable.hide()
	var indicator := box(device,"StateIndicator",Vector3(.48,.05,.27),Vector3(.07,.28,.07),material(BRASS,.7))
	controls.append({"device":device,"visual":visual,"indicator":indicator})

func build_exit() -> void:
	exit_material = material(BRASS,.35)
	var sign := Node3D.new()
	sign.name = "ExitGuide"
	sign.position = Vector3(40.8,1.65,-1.5)
	add_child(sign)
	box(sign,"Backplate",Vector3.ZERO,Vector3(.95,.48,.06),material(Color(.07,.11,.10)))
	box(sign,"ArrowShaft",Vector3(0,0,.05),Vector3(.56,.055,.035),exit_material)
	for direction in [-1,1]:
		var tip := box(sign,"ArrowTip",Vector3(.24,direction*.085,.05),Vector3(.27,.055,.035),exit_material)
		tip.rotation.z = -direction * PI/4
	exit_path = Node3D.new()
	exit_path.name = "OpenExitPath"
	add_child(exit_path)
	for x in [39.0,40.3,41.6,42.9,44.2]:
		for direction in [-1,1]:
			var tip := box(exit_path,"Inlay",Vector3(x,.035,direction*.16),Vector3(.45,.018,.045),exit_material)
			tip.rotation.y = direction * PI/4
	exit_light = OmniLight3D.new()
	exit_light.name = "ExitWarmLight"
	exit_light.position = Vector3(42.8,1.7,.2)
	exit_light.light_color = Color(1,.73,.35)
	exit_light.omni_range = 5.5
	add_child(exit_light)

func update(_delta: float) -> void:
	for id in plates:
		var frame: Node3D = plates[id]
		var active: bool = room.objects[id].satisfied()
		frame.set_meta("active",active)
		frame.get_node("Deck").position.y = .002 if active else .018
		for child in frame.get_children():
			if child is MeshInstance3D and child != frame.get_node("Deck"):
				child.material_override.albedo_color = ACTIVE if active else BRASS
				child.material_override.emission = ACTIVE if active else BRASS
	for entry in controls:
		var device: Node3D = entry.device
		var active: bool = device.satisfied()
		entry.indicator.material_override.albedo_color = ACTIVE if active else BRASS
		entry.indicator.material_override.emission = ACTIVE if active else BRASS
		var lever: Node3D = entry.visual.find_child("Lever",true,false)
		if lever: lever.rotation.z = .45 if active else -.45
		var rotor: Node3D = entry.visual.find_child("Rotor",true,false)
		if rotor and device.spec.kind == "selector": rotor.rotation.z = float(device.state) * PI / 3
		var bell: Node3D = entry.visual.find_child("Bell",true,false)
		if bell: bell.rotation.z = .2 if active else 0
	exit_path.visible = room.completed
	exit_light.light_energy = 2.2 if room.completed else 0.0
	exit_material.emission_energy_multiplier = 1.4 if room.completed else .35

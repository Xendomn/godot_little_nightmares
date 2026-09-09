extends Node3D
## A conserved water circuit drives the rendered surface and physical float decks.
const Circuit = preload("res://scripts/puzzles/water_circuit.gd")
const Basin = preload("res://scenes/props/water_basin.tscn")
var room: Node3D
var kind := ""
var circuit = Circuit.new()
var basins: Array[Node3D] = []
var floats: Array[AnimatableBody3D] = []
var hatch: AnimatableBody3D
var piston: Node3D
var gauge: Node3D
var warning: Label3D
var warning_lamp: OmniLight3D
var submerged_time := 0.0
var drive_pressure := 0.0
var piston_extension := 0.0

func setup(owner_room: Node3D) -> void:
	room = owner_room
	kind = str(room.spec.machine)
	name = "WaterMechanisms"
	basins.append(room.water)
	if kind == "drain_water":
		circuit.left = 1.9
	else:
		room.water.position.x = 20
		room.water.scale.x = .375
	if kind == "floating_raft":
		room.objects.fill.position.x = 18.2
		room.objects.crate.min_x = room.global_position.x + 14
		room.objects.crate.max_x = room.global_position.x + 22
		hatch = room.solid("FloatHatch", Vector3(21.5,2.2,0), Vector3(3,.2,3.6), room.base_color, true)
		room.solid("FixedTankGrate", Vector3(17.5,2.2,0), Vector3(1,.2,3.6), room.base_color)
		# Deck boards mark the aperture and make crate alignment visible from the bank.
		for x in [20.0,23.0]: visual(self,Vector3(x,1,-1.8),Vector3(.1,2,.1),Color(.6,.47,.2))
	if kind == "twin_water":
		circuit.right = 1.9
		room.spec["ladder_lock"] = "right_valve"
		var right_basin := Basin.instantiate()
		right_basin.name = "RightWaterBasin"
		right_basin.position = Vector3(33,0,0)
		right_basin.scale.x = .375
		room.add_child(right_basin)
		basins.append(right_basin)
		var upper = room.get_node("UpperWalk")
		room.remove_child(upper)
		upper.queue_free()
		room.solid("CentralDryLedge",Vector3(26,3.05,0),Vector3(6,.3,3.6),room.base_color)
		room.solid("RightExitLanding",Vector3(36.75,3.05,0),Vector3(2.5,.3,3.6),room.base_color)
		room.ladder.position.x = 38.6
		room.ladder.top_exit.x = -1.1
		make_float("LeftFloat",20)
		make_float("RightFloat",33)
		boarding_steps()
	if kind == "hydraulic_head":
		make_float("PressureFloat",21)
		boarding_steps()
		visual(self,Vector3(38,2.6,-1.6),Vector3(1.6,.8,.35),Color(.22,.32,.32))
		piston = visual(self,Vector3(37.4,2.6,-1.4),Vector3(1,.25,.25),Color(.65,.53,.27))
		gauge = Node3D.new()
		gauge.position = Vector3(36,3,-1.5)
		add_child(gauge)
		visual(gauge,Vector3(0,.3,0),Vector3(.08,.6,.1),Color(.88,.64,.2))
		for i in 7:
			var angle := -PI*.75 + float(i)*PI*1.5/6
			visual(self,Vector3(36+sin(angle)*.7,3+cos(angle)*.7,-1.5),Vector3(.09,.09,.12),Color(.64,.72,.64))
	for basin in basins:
		for i in 5:
			visual(self,Vector3(basin.position.x-2.85,.15+i*.45,-1.85),Vector3(.3,.045,.08),Color(.68,.77,.65))
		visual(self,Vector3(basin.position.x-2.85,1,-1.86),Vector3(.05,2,.08),Color(.68,.77,.65))
	warning = Label3D.new()
	warning.name = "DeepWaterWarning"
	warning.text = "水太深 · 立即返回高处"
	warning.font_size = 30
	warning.pixel_size = .009
	warning.modulate = Color(1,.3,.12)
	warning.no_depth_test = true
	add_child(warning)
	warning.hide()
	warning_lamp = OmniLight3D.new()
	warning_lamp.light_color = Color(1,.2,.06)
	warning_lamp.omni_range = 3
	add_child(warning_lamp)
	warning_lamp.hide()
	refresh(0,true)

func visual(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = .5
	material.roughness = .5
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

func make_float(label: String, x: float) -> void:
	var body: AnimatableBody3D = room.solid(label,Vector3(x,.25,0),Vector3(4,.8,3.4),Color(.3,.34,.25),true)
	floats.append(body)
	for z in [-1.3,1.3]:
		visual(body,Vector3(0,-.2,z),Vector3(3.7,.6,.5),Color(.39,.28,.14))
	for offset in [-1.9,1.9]:
		visual(self,Vector3(x+offset,1.4,-1.9),Vector3(.09,3,.09),Color(.48,.52,.48))

func boarding_steps() -> void:
	room.solid("BoardingStep",Vector3(14.7,.3,0),Vector3(1.4,.6,3.4),room.base_color)
	room.solid("BoardingBank",Vector3(16.5,.675,0),Vector3(2,1.35,3.4),room.base_color)

func condition(expression: String) -> Variant:
	match expression:
		"water_low": return circuit.left <= .2
		"water_high", "left_high": return circuit.left >= 1.75
		"right_high": return circuit.right >= 1.75
		"raft_high":
			if kind != "floating_raft": return false
			var crate: Node3D = room.objects.crate
			return crate.position.x >= 20 and crate.position.x <= 22.5 and absf(crate.position.z) < 1.2 and crate.position.y >= 1.5
		"hydraulic_ready": return circuit.vented and state("pressure") == 2 and drive_pressure >= .8 and piston_extension >= .95
	return null

func state(id: String) -> int:
	return int(room.objects[id].state) if room.objects.has(id) else 0

func tick(delta: float) -> void:
	match kind:
		"drain_water":
			if state("inlet") == 1: circuit.fill(delta)
			elif state("drain") == 1: circuit.drain(delta)
		"floating_raft":
			if state("fill") == 1: circuit.fill(delta)
			elif state("fill") == 2: circuit.drain(delta)
		"twin_water":
			if state("upper_transfer") == 1 and room.met("left_valve"): circuit.transfer(delta,false)
			elif state("transfer") == 1: circuit.transfer(delta,true)
			elif state("transfer") == 2: circuit.transfer(delta,false)
		"hydraulic_head":
			if state("pressure") == 1 and room.met("bypass"): circuit.fill(delta)
			circuit.vented = room.met("vent")
			drive_pressure = circuit.pressure() if state("pressure") == 2 and room.met("bypass") else 0.0
			piston_extension = move_toward(piston_extension,drive_pressure,delta*.8)
	refresh(delta)
	check_submersion(delta)

func refresh(delta: float, immediate: bool = false) -> void:
	for i in basins.size(): basins[i].set_water_level(maxf(-.05,(circuit.left if i == 0 else circuit.right)-.04))
	for i in floats.size():
		var target: float = .25 + (circuit.left if i == 0 else circuit.right)
		floats[i].position.y = target if immediate else move_toward(floats[i].position.y,target,delta*1.2)
	if hatch:
		hatch.position.y = 5.2 if state("roof_hatch") == 1 else 2.2
		var crate: CharacterBody3D = room.objects.crate
		var floating: bool = crate.position.x >= 17.5 and crate.position.x <= 22.5 and absf(crate.position.z) < 1.5
		var bottom := maxf(.02,circuit.left-.25)
		var under_fixed_grate: bool = crate.position.x-.5 < 18.0
		var under_closed_hatch: bool = state("roof_hatch") == 0 and crate.position.x+.5>20 and crate.position.x-.5<23
		if under_fixed_grate or under_closed_hatch: bottom = minf(bottom,2.1-crate.size.y-.03)
		crate.buoyancy_target = room.global_position.y + bottom if floating else NAN
	if piston:
		piston.position.x = 37.4+piston_extension
		gauge.rotation.z = lerpf(PI*.75,-PI*.75,drive_pressure)

func check_submersion(delta: float) -> void:
	if room.chapter == null or not is_instance_valid(room.chapter.player) or not room.chapter.playing or room.chapter.respawning:
		return
	var p: Vector3 = room.local_player()
	var underwater := false
	for i in basins.size():
		var basin := basins[i]
		var depth: float = circuit.left if i == 0 else circuit.right
		if absf(p.x-basin.position.x) < 8*basin.scale.x and absf(p.z) < 2.05 and p.y+.9 < depth:
			underwater = true
	submerged_time = submerged_time + delta if underwater else 0.0
	warning.visible = underwater
	warning_lamp.visible = underwater
	if underwater:
		warning.position = p+Vector3(0,1.8,.1)
		warning_lamp.position = p+Vector3(0,1,.2)
		warning_lamp.light_energy = 1.2 + sin(submerged_time*14)*.6
		if submerged_time >= 1.25:
			submerged_time = 0
			room.chapter.fail()

func capture_state() -> Dictionary:
	return {"circuit":circuit.capture_state(),"float_y":floats.map(func(body): return body.position.y),"pressure":drive_pressure,"piston":piston_extension}

func restore_state(data: Dictionary) -> void:
	var defaults := {"left":1.9 if kind == "drain_water" else 0.0,"right":1.9 if kind == "twin_water" else 0.0,"vented":false}
	circuit.restore_state(data.get("circuit",defaults))
	drive_pressure = clampf(float(data.get("pressure",0)),0,1)
	piston_extension = clampf(float(data.get("piston",0)),0,1)
	submerged_time = 0
	warning.hide()
	warning_lamp.hide()
	refresh(0,true)
	var heights: Array = data.get("float_y",[])
	for i in mini(heights.size(),floats.size()): floats[i].position.y = float(heights[i])

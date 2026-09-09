extends Node3D
## Room integration for deterministic mechanisms. Controls and visuals share state.
const WeightMotion = preload("res://scripts/puzzles/counterweight_motion.gd")
const ShaftClock = preload("res://scripts/puzzles/shaft_clock.gd")
const HazardCycle = preload("res://scripts/puzzles/hazard_cycle.gd")
var room: Node3D
var kind := ""
var weight_motion = WeightMotion.new()
var shafts = ShaftClock.new()
var cycles: Array = []
var hazard_origins: Array[float] = []
var hazard_visuals: Array[Node3D] = []
var water_machine: Node3D
var caught := false
var ram_height := 2.9
var rack := 0.0
var travel_target := 0
var exchange_heights := [-.09,1.51]
var exchange_bodies: Array = []
var pinned_body: AnimatableBody3D
var rack_body: Node3D
var ram_body: AnimatableBody3D
var fast_pointer: Node3D
var slow_pointer: Node3D
var target_pointer: Node3D
var clock_face: Node3D
var connections: Array = []
var span_pins: Array = []

func setup(owner_room: Node3D) -> void:
	room = owner_room
	kind = str(room.spec.get("machine",""))
	name = "Machines"
	if kind == "weight_lift": travel_target = 1
	if kind in ["drain_water","floating_raft","twin_water","hydraulic_head"]:
		var water_script = load("res://scripts/puzzles/water_puzzles.gd")
		if water_script:
			water_machine = water_script.new()
			add_child(water_machine)
			water_machine.setup(room)
	if room.lift != null:
		add_control("lift_trip","travel",Vector3(21,.8,-.9),"货篮行程杆")
		if not room.objects.has("call_lower"): add_control("call_lower","travel",Vector3(17,.8,-.9),"下层货篮呼叫")
		if not room.objects.has("call_upper"): add_control("call_upper","travel",Vector3(25,4,-.9),"上层货篮呼叫")
		line(Vector3(21,6,-1.4),Vector3(21,.1,-1.4),Color(.5,.42,.24))
	if kind == "cargo_catch":
		rack_body = room.solid("CargoPawl",Vector3(26.65,.28,0),Vector3(.15,.56,1.3),Color(.64,.43,.16))
	if kind == "support_press":
		if room.press_visual:
			var old_ram = room.press_visual.find_child("Ram",true,false)
			if old_ram: old_ram.visible = false
		ram_body = room.solid("ContactRam",Vector3(23,ram_height,0),Vector3(2.4,.35,3.5),Color(.4,.3,.14),true)
		var frame := box(room.objects.crate,Vector3(0,1.35,-.3),Vector3(.85,.75,.18),Color(.58,.43,.18))
		frame.name="LoadBearingFrame"
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size=Vector3(.85,.75,.18)
		collision.shape=shape
		collision.position=frame.position
		room.objects.crate.add_child(collision)
	if kind == "rack_drive":
		rack_body = room.solid("DoorRack",Vector3(34,2.5,-1.8),Vector3(3,.3,.25),Color(.63,.43,.16))
		for x in range(12): box(rack_body,Vector3(x*.24-1.4,-.24,0),Vector3(.12,.18,.22),Color(.6,.4,.16))
	if kind == "weight_exchange":
		room.get_node("UpperWalk").free()
		room.solid("ExchangeExitLanding",Vector3(37,3.05,0),Vector3(7,.3,3.4),room.base_color)
		room.ladder.position.x=41.1
		# Steps keep the reset route reachable; the island is permanent.
		exchange_bodies.append(room.solid("LeftTrayPlatform",Vector3(18,-.09,0),Vector3(5,.18,3.4),room.base_color,true))
		room.solid("ExchangeIsland",Vector3(24,1.5,0),Vector3(7,.2,3.4),room.base_color)
		exchange_bodies.append(room.solid("RightTrayPlatform",Vector3(30,1.51,0),Vector3(5,.18,3.4),room.base_color,true))
		var ramp = room.solid("ReturnRamp",Vector3(13.5,.69,0),Vector3(4.5,.2,3.4),room.base_color)
		ramp.rotation.z=.38
		room.objects.upper.position.x=29
	if kind == "pinned_bridge":
		room.get_node("UpperWalk").free()
		room.solid("BridgeLanding",Vector3(32,3.05,0),Vector3(7,.3,3.4),room.base_color)
		room.ladder.position.x=36.2
		pinned_body = room.solid("PinnedWalk",Vector3(26,1.2,0),Vector3(5,.25,3.4),room.base_color,true)
	if kind == "freight_shaft":
		# A waist-high grate separates the walking aisle from cargo; item can be put over it.
		for mesh in room.lift.get_children():
			if mesh is CollisionShape3D: mesh.shape.size.z=1.5
			if mesh is MeshInstance3D and mesh.mesh is BoxMesh: mesh.mesh.size.z=1.5
		room.solid("CargoRail",Vector3(19.0,.175,0),Vector3(.15,.35,1.5),room.base_color)
		var cage = room.solid("CargoCageRoof",Vector3(21,.85,0),Vector3(4.2,.15,1.5),room.base_color)
		cage.reparent(room.lift)
		room.objects.lift_trip.remove_from_group("puzzle_interactable")
		room.objects.lift_trip.hide()
	if kind == "bell_decoy":
		room.solid("QuietCover",Vector3(14,1.1,-.35),Vector3(1.0,2.2,1.2),room.base_color)
		room.model(room,"rack",Vector3(14,0,-.35),Vector3(.65,1,.55))
		var rear_bell = load("res://assets/models/props/bell.glb").instantiate()
		rear_bell.position=Vector3(9,1.5,-2.6)
		rear_bell.scale=Vector3.ONE*.35
		add_child(rear_bell)
		line(Vector3(9,.8,-.9),Vector3(9,2.6,-2.6),Color(.62,.45,.2))
	if kind in ["shaft_sync","clock_alignment"]: build_clock()
	if room.spec.has("hazards"): build_hazards()
	build_connections()
	build_mechanical_clues()
	for i in room.bridge_bodies.size():
		var pin := box(self,Vector3([18,28,37][i],.4,-1.65),Vector3(.6,.15,.2),Color(.7,.45,.16))
		span_pins.append(pin)
	refresh_visuals()

func add_control(id: String, type: String, pos: Vector3, label: String) -> Node3D:
	var control = preload("res://scripts/puzzles/device.gd").new()
	control.name = id
	control.object_id = id
	control.spec = {"id":id,"kind":type,"needs":[],"display_name":label}
	control.room = room
	control.position = pos
	room.add_child(control)
	room.objects[id] = control
	return control

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = .6
	mat.roughness = .55
	visual.material_override = mat
	parent.add_child(visual)
	return visual

func line(a: Vector3, b: Vector3, color: Color) -> MeshInstance3D:
	var visual := box(self,(a+b)*.5,Vector3(.045,a.distance_to(b),.045),color)
	if a.distance_to(b)>.001: visual.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return visual

func build_connections() -> void:
	for device in room.objects.values():
		if not device.has_method("satisfied"): continue
		for expression in device.spec.get("needs",[]):
			var source = room.objects.get(str(expression).get_slice(":",0))
			if source == null: continue
			var a: Vector3 = source.position + Vector3(0,.25,0)
			var b: Vector3 = device.position + Vector3(0,.25,0)
			a.z = -1.8
			b.z = -1.8
			connections.append({"mesh":line(a,b,Color(.35,.28,.15)),"condition":str(expression)})

func build_mechanical_clues() -> void:
	var brass := Color(.65,.48,.23)
	if water_machine:
		for basin in water_machine.basins:
			line(Vector3(basin.position.x,.25,-2),Vector3(basin.position.x,2.4,-2),brass)
		if kind == "twin_water": line(Vector3(20,.25,-2),Vector3(33,.25,-2),brass)
		elif kind == "hydraulic_head": line(Vector3(21,.25,-2),Vector3(38,.25,-2),brass)
	if kind in ["weight_lift","weight_exchange","pinned_bridge"]:
		var deck_x: Array = [18,30] if kind=="weight_exchange" else [21]
		for x in deck_x:
			line(Vector3(x,.1,-1.7),Vector3(x,5.8,-1.7),brass)
			room.model(self,"winch",Vector3(x,4.5,-1.9),Vector3.ONE*.4)
			for height in [1.6,3.2]: box(self,Vector3(x-.5,height,-1.65),Vector3(1,.06,.08),brass)
		if kind=="weight_lift":
			for x in [10,14]: line(Vector3(x,1.2,-1.8),Vector3(21,5.8,-1.8),brass)
		if kind=="weight_exchange":
			line(Vector3(10,1.2,-1.8),Vector3(18,5.8,-1.8),brass)
			line(Vector3(30,5.8,-1.8),Vector3(30,2,-1.8),brass)
	if kind=="rack_drive":
		line(Vector3(32,3,-1.6),Vector3(30,3,-1.6),brass)
		line(Vector3(30,3,-1.6),Vector3(30.5,3.3,-1.6),brass)
		line(Vector3(30,3,-1.6),Vector3(30.5,2.7,-1.6),brass)
	if room.spec.get("hazards","")=="steam":
		for x in [18,24,30,36]: box(self,Vector3(x,.015,0),Vector3(2.4,.025,2.8),Color(.25,.36,.34))

func build_clock() -> void:
	clock_face = Node3D.new()
	clock_face.position = Vector3(26,3.2,-1.6)
	add_child(clock_face)
	for i in 24:
		var angle := float(i)*TAU/24
		box(clock_face,Vector3(sin(angle)*1.7,cos(angle)*1.7,0),Vector3(.06,.16,.07),Color(.7,.6,.3))
	fast_pointer = Node3D.new()
	clock_face.add_child(fast_pointer)
	box(fast_pointer,Vector3(0,.65,.12),Vector3(.09,1.3,.08),Color(.85,.57,.17))
	slow_pointer = Node3D.new()
	clock_face.add_child(slow_pointer)
	box(slow_pointer,Vector3(0,.5,.25),Vector3(.14,1,.1),Color(.3,.85,.8))
	target_pointer = Node3D.new()
	clock_face.add_child(target_pointer)
	box(target_pointer,Vector3(0,1.7,.15),Vector3(.85,.15,.12),Color(.65,.8,.6))
	if kind == "shaft_sync": target_pointer.hide()
	else: fast_pointer.hide()

func build_hazards() -> void:
	for old in room.hazards: old.queue_free()
	for old in room.danger_lights: old.queue_free()
	room.hazards.clear()
	room.danger_lights.clear()
	hazard_origins.assign([21.0,32.0] if room.spec.hazards == "pendulum" else [21.0,27.0,33.0])
	for i in hazard_origins.size():
		var cycle = HazardCycle.new()
		cycle.time = i*3.0 if room.spec.hazards == "steam" else i*2.5
		cycles.append(cycle)
		var visual := Node3D.new()
		visual.position = Vector3(hazard_origins[i],0,0)
		add_child(visual)
		if room.spec.hazards == "pendulum":
			var pivot := Node3D.new()
			pivot.name = "Swing"
			pivot.position.y = 4.1
			visual.add_child(pivot)
			box(pivot,Vector3(0,-1.3,0),Vector3(.08,2.6,.1),Color(.48,.36,.18))
			box(pivot,Vector3(0,-2.6,0),Vector3(.9,.9,3.4),Color(.68,.46,.19))
		else:
			room.model(visual,"steam_pipe" if ResourceLoader.exists("res://assets/models/expansion/steam_pipe.glb") else "generator",Vector3(0,0,-1.5),Vector3(.5,.5,.5))
			var plume := box(visual,Vector3(0,1.0,0),Vector3(.65,2,3.6),Color(.65,.85,.85,.4))
			plume.name = "Steam"
			plume.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0,2.4,1)
		lamp.omni_range = 3
		visual.add_child(lamp)
		room.danger_lights.append(lamp)
		room.hazards.append(visual)
		hazard_visuals.append(visual)

func condition(expression: String) -> Variant:
	if water_machine:
		var result = water_machine.condition(expression)
		if result != null: return result
	match expression:
		"cargo_caught": return caught and absf(room.objects.crate.position.x-26)<.9
		"press_supported": return room.met("power:1") and room.met("limiter") and ram_height<=1.95
		"rack_open": return rack >= 2.95
		"weight_high": return weight_motion.height>3.0
		"exchange_left": return float(exchange_heights[0])>1.4
		"exchange_right": return float(exchange_heights[1])>3.0
		"bridge_supported": return pinned_body != null and pinned_body.position.y>2.95
		"cargo_at_top": return room.lift != null and room.lift.position.y>3.0
		"shafts_aligned": return shafts.aligned()
		"clock_aligned": return shafts.at_mark(int(room.objects.phase.state))
		"span_a_ready", "span_b_ready", "span_c_ready":
			var i := ["span_a_ready","span_b_ready","span_c_ready"].find(expression)
			return room.bridge_bodies.size()>i and room.bridge_bodies[i].position.y>-.2
	return null

func control_used(device: Node3D) -> void:
	if water_machine and water_machine.has_method("control_used"): water_machine.control_used(device)
	if device.object_id == "call_lower": travel_target = 0
	elif device.object_id == "call_upper": travel_target = 1
	elif device.object_id == "lift_trip": travel_target = 1-travel_target
	if kind == "shaft_sync" and device.object_id == "fast_axis": shafts.coupled = true

func lift_target(delta: float) -> Variant:
	if room.lift == null: return null
	if kind == "freight_shaft": return 3.11 if room.met("hoist:1") else -.09
	if kind == "clutch_stop" and room.met("shortcut"): return 3.11
	if kind == "weight_lift":
		var mass := 0.0
		for id in ["tray_a","tray_b"]:
			var part = room.objects[id].occupied
			if is_instance_valid(part): mass += part.mass
		weight_motion.advance(delta,mass if travel_target else 0.0)
		return weight_motion.height
	return 3.11 if travel_target and room.met(str(room.spec.get("lift",""))) else -.09

func tick(delta: float) -> void:
	if water_machine: water_machine.tick(delta)
	if room.lift and room.objects.has("lift_trip"):
		room.objects.lift_trip.position = room.lift.position + Vector3(-1.1,.85,-.7)
	if kind == "cargo_catch":
		caught = absf(room.objects.crate.position.x-26)<.85
	if kind == "support_press":
		var target := 2.9
		if room.met("power:1"): target = 1.9 if room.met("limiter") else 1.7 + sin(room.phase*1.3)*1.2
		ram_height = move_toward(ram_height,target,delta*1.4)
		ram_body.position.y = ram_height
		if room.chapter and room.met("power:1") and not room.met("limiter"):
			var p: Vector3 = room.local_player()
			if absf(p.x-23)<1.15 and p.y+1.0>ram_height-.2: room.chapter.fail()
	if kind == "rack_drive":
		var target := 3.0 if room.met("direction:2") else 0.0
		rack = move_toward(rack,target,delta*.8)
	if kind == "weight_exchange":
		exchange_heights[0] = move_toward(float(exchange_heights[0]),1.51 if room.met("lower") or room.met("stop") else -.09,delta)
		exchange_heights[1] = move_toward(float(exchange_heights[1]),3.11 if room.met("upper") else 1.51,delta)
		for i in 2: exchange_bodies[i].position.y = exchange_heights[i]
		room.objects.upper.position=exchange_bodies[1].position+Vector3(-.5,.8,-.9)
	if kind == "pinned_bridge": pinned_body.position.y = move_toward(pinned_body.position.y,3.05 if room.met("tray") or room.met("pin") else 1.2,delta)
	if kind == "shaft_sync": shafts.advance(delta,room.met("lift_power") and room.met("slow_axis"),room.met("sync_brake"))
	if kind == "clock_alignment": shafts.advance(delta,room.met("counterweight"),false,room.met("clock_brake"))
	for i in cycles.size():
		var stopped: bool = room.met("brake_a" if i==0 else "brake_b")
		if room.spec.hazards == "steam": stopped = not room.met("timing:2")
		if room.theme=="clocktower" and room.index==5 and not room.met("release"): stopped=true
		cycles[i].advance(delta,stopped)
	refresh_visuals()
	check_hazards()

func refresh_visuals() -> void:
	if rack_body and kind=="rack_drive": rack_body.position.x=34-rack
	if fast_pointer: fast_pointer.rotation.z=-shafts.fast
	if slow_pointer: slow_pointer.rotation.z=-shafts.slow
	if target_pointer and kind=="clock_alignment": target_pointer.rotation.z=-float(room.objects.phase.state)*PI*.5
	for connection in connections:
		var mat: StandardMaterial3D = connection.mesh.material_override
		mat.albedo_color = Color(.28,.75,.65) if room.met(connection.condition) else Color(.35,.28,.15)
	for i in span_pins.size(): span_pins[i].position.z=-1.2 if room.met(["pin_a","pin_b","pin_c"][i]) else -1.65
	for i in cycles.size():
		var stage: String
		if room.spec.hazards=="pendulum":
			hazard_visuals[i].get_node("Swing").rotation.z=cycles[i].angle()
			stage=cycles[i].pendulum_stage()
		else:
			stage=cycles[i].steam_stage() if room.met("timing:2") else "warning"
			hazard_visuals[i].get_node("Steam").visible=stage=="active"
		room.danger_lights[i].light_color={"active":Color(1,.15,.02),"warning":Color(1,.65,.1),"safe":Color(.2,.9,.72)}[stage]

func check_hazards() -> void:
	if room.chapter==null or not room.chapter.playing or room.chapter.respawning: return
	for i in cycles.size():
		var p: Vector3 = room.local_player()-Vector3(hazard_origins[i],0,0)
		var hit: bool
		if room.spec.hazards=="pendulum": hit=cycles[i].hits_pendulum(p,.66 if room.chapter.player.crouching else 1.24)
		else: hit=room.met("timing:2") and cycles[i].steam_stage()=="active" and absf(p.x)<.5 and absf(p.z)<2.05 and p.y<2
		if hit: room.chapter.fail()

func capture_state() -> Dictionary:
	return {"water":water_machine.capture_state() if water_machine else {},"weight":weight_motion.capture_state(),"shafts":shafts.capture_state(),"cycles":cycles.map(func(c): return c.capture_state()),"caught":caught,"ram_height":ram_height,"rack":rack,"travel_target":travel_target,"exchange_heights":exchange_heights.duplicate(),"pinned_y":pinned_body.position.y if pinned_body else 1.2}

func restore_state(data: Dictionary) -> void:
	weight_motion.restore_state(data.get("weight",{}))
	shafts.restore_state(data.get("shafts",{}))
	var states: Array = data.get("cycles",[])
	for i in cycles.size(): cycles[i].restore_state(states[i] if i<states.size() else {"time":i*3.0 if room.spec.hazards=="steam" else i*2.5})
	caught=bool(data.get("caught",false))
	ram_height=float(data.get("ram_height",2.9))
	rack=float(data.get("rack",0))
	travel_target=int(data.get("travel_target",0))
	exchange_heights=data.get("exchange_heights",[-.09,1.51]).duplicate()
	if ram_body: ram_body.position.y=ram_height
	if pinned_body: pinned_body.position.y=float(data.get("pinned_y",1.2))
	for i in exchange_bodies.size(): exchange_bodies[i].position.y=exchange_heights[i]
	if water_machine: water_machine.restore_state(data.get("water",{}))
	if room.lift and room.objects.has("lift_trip"): room.objects.lift_trip.position=room.lift.position+Vector3(-1.1,.85,-.7)
	refresh_visuals()

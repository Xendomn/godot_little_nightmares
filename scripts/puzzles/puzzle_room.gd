extends Node3D
signal guidance_changed
## One authored machine bay, with local persistent registry and reversible inputs.
const DEVICE = preload("res://scripts/puzzles/device.gd")
const CARRY = preload("res://scripts/puzzles/carry_item.gd")
const PUSH = preload("res://scripts/puzzles/pushable.gd")
const LADDER = preload("res://scripts/puzzles/ladder.gd")
@export var spec: Dictionary
@export var theme := "workshop"
@export var index := 0
var chapter: Node3D
var objects: Dictionary = {}
var completed := false
var ladder_unlocked := false
var fuse_revealed := false
var guidance_text := ""
var presentation: Node3D
var phase := 0.0
var lift: AnimatableBody3D
var gate: AnimatableBody3D
var water: MeshInstance3D
var hazards: Array = []
var initial: Dictionary
var press_visual: Node3D
var bridge_bodies: Array = []
var danger_lights: Array = []
var ladder: Node3D
var speaker: AudioStreamPlayer3D
var base_color := Color(.19,.16,.11)

func _ready() -> void:
	base_color = {"workshop":Color(.24,.18,.10),"laundry":Color(.10,.22,.24),"thread_vault":Color(.17,.14,.20),"clocktower":Color(.23,.19,.11)}[theme]
	build()
	presentation = preload("res://scripts/puzzles/puzzle_presentation.gd").new()
	presentation.name = "PuzzlePresentation"
	add_child(presentation)
	presentation.setup(self)
	update_fuse_presence()
	initial = capture_state()

func solid(label: String, pos: Vector3, size: Vector3, color: Color, moving: bool = false) -> PhysicsBody3D:
	var body: PhysicsBody3D = AnimatableBody3D.new() if moving else StaticBody3D.new()
	body.name = label
	body.position = pos
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var geom := BoxMesh.new()
	geom.size = size
	mesh.mesh = geom
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .8
	mesh.material_override = material
	body.add_child(mesh)
	return body

func model(parent: Node3D, asset: String, pos: Vector3 = Vector3.ZERO, scale_value: Vector3 = Vector3.ONE) -> Node3D:
	var path := "res://assets/models/expansion/" + asset + ".glb"
	if not ResourceLoader.exists(path): return null
	var visual = load(path).instantiate()
	visual.name = "Visual"
	visual.position = pos
	visual.scale = scale_value
	parent.add_child(visual)
	return visual

func add_arch_collision(arch: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "ArchCollision"
	arch.add_child(body)
	# Match authored structural parts; thin brass trim does not need collision.
	for mesh in arch.find_children("*", "MeshInstance3D", true, false):
		if not (str(mesh.name).contains("Fluted") or str(mesh.name).contains("Plinth") or str(mesh.name).contains("Segmented")):
			continue
		var bounds: AABB = mesh.mesh.get_aabb()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = bounds.size
		shape.shape = box
		body.add_child(shape)
		shape.global_transform = mesh.global_transform * Transform3D(Basis.IDENTITY, bounds.get_center())

func build() -> void:
	if spec.get("bridges",false):
		for segment in [[0,14],[18,23],[27,32],[36,46]]:
			solid("Island",Vector3((segment[0]+segment[1])*.5,-.35,0),Vector3(segment[1]-segment[0],.7,5),base_color)
		for x in [16,25,34]:
			bridge_bodies.append(solid("Span",Vector3(x,-3,0),Vector3(4,.3,4),base_color,true))
	else:
		var floor_body := solid("Floor",Vector3(23,-.35,0),Vector3(46,.7,5),base_color)
		# Boards finish at y=0. Keep their backing below them, without changing footing.
		for child in floor_body.get_children():
			if child is MeshInstance3D: child.position.y -= .025
	solid("Backwall",Vector3(23,4,-2.4),Vector3(46,8,.3),base_color*.6)
	for x in range(0,46,4):
		model(self,"wall_panel",Vector3(x,0,-2.1))
		model(self,"wall_panel",Vector3(x,5,-2.1))
		if x % 12 == 4:
			var asset: String = {"workshop":"generator","laundry":"tank","thread_vault":"rack","clocktower":"gear"}[theme]
			model(self,asset,Vector3(x,3.6,-1.7),Vector3(2.5,2.5,1))
		if not spec.get("bridges",false): model(self,"floor_panel",Vector3(x,-.20,0))
		if x % 8 == 0:
			var arch := model(self,"arch",Vector3(x,0,0),Vector3(1.2,1.8,1))
			arch.rotation.y = PI / 2
			add_arch_collision(arch)
			arch.add_child(preload("res://scripts/puzzles/foreground_arch.gd").new())
			model(self,"lamp",Vector3(x+1,3.9,-1.5))
			var light := OmniLight3D.new()
			light.position = Vector3(x+1,3.8,.1)
			light.light_color = Color(.53,.8,.87) if theme == "laundry" else Color(1,.69,.34)
			light.light_energy = 1.6
			light.omni_range = 8
			add_child(light)
	gate = solid("ExitGate",Vector3(42,2,0),Vector3(.45,4,4.7),base_color,true)
	model(gate,"gate",Vector3(0,-2,0),Vector3(.15,1.34,12))
	for entry in spec.devices:
		var device = DEVICE.new()
		device.object_id = entry.id
		device.name = entry.id
		device.spec = entry
		device.room = self
		device.position = Vector3(entry.x,entry.y,entry.z)
		if entry.kind == "plate": device.position = Vector3(entry.x,.02,0)
		add_child(device)
		objects[entry.id] = device
		if entry.kind == "plate":
			solid(entry.id+"Mark",Vector3(entry.x,-.02,0),Vector3(1.8,.02,2.2),Color(.56,.40,.10))
		else:
			model(device,"control_pedestal",Vector3(0,-.8,-.25),Vector3(.8,.62,.8))
			model(device,"selector" if entry.kind == "selector" else ("clutch" if entry.kind == "brake" else "valve"),Vector3(0,0,-.3),Vector3(.65,.65,.65))
			var label := Label3D.new()
			label.text = {"selector":"〇  I  II  III", "socket":"◉", "brake":"Ⅱ", "latch":"↳", "plate":"◇"}.get(entry.kind,"")
			label.font_size = 26
			label.pixel_size = .007
			label.position = Vector3(0,.95,-.1)
			label.modulate = Color(.65,.8,.77)
			device.add_child(label)
	for entry in spec.items:
		var thing = CARRY.new()
		thing.object_id = entry.id
		thing.name = entry.id
		thing.item_kind = entry.kind
		thing.position = Vector3(entry.x,entry.y,entry.z)
		add_child(thing)
		model(thing,entry.kind,Vector3.ZERO,Vector3(.55,.55,.55))
		objects[entry.id] = thing
	if spec.has("crate"):
		var crate = PUSH.new()
		crate.object_id = "crate"
		crate.name = "crate"
		crate.position = Vector3(spec.crate,.03,0)
		crate.min_x = global_position.x+2
		crate.max_x = global_position.x+38
		crate.lane_z = 0
		crate.mass = 3
		add_child(crate)
		model(crate,"floating_crate")
		objects.crate = crate
	if spec.get("upper",false):
		# Separate lift well at x=21; upper walkway begins beside it, not over it.
		solid("UpperWalk",Vector3(29,3.05,0),Vector3(12,.3,3.6),base_color)
		lift = solid("Lift",Vector3(21,-.09,0),Vector3(4.2,.18,3.4),base_color,true)
		# At the bottom stop, separate the platform skin from boards and their backing.
		for child in lift.get_children():
			if child is MeshInstance3D: child.position.y -= .01
		model(lift,"cargo_basket",Vector3(0,.09,0),Vector3(1.4,.15,1.8))
		ladder = LADDER.new()
		ladder.name = "ReturnLadder"
		ladder.object_id = "ladder"
		ladder.position = Vector3(35.7,0,0)
		ladder.height = 3.23
		ladder.top_exit = Vector3(-1.1,3.23,0)
		ladder.has_top_exit = true
		add_child(ladder)
		model(ladder,"ladder",Vector3(0,0,-.35))
		objects.ladder = ladder
	if spec.get("belt",false): model(self,"conveyor",Vector3(19,-.53,0),Vector3(3.5,1,1))
	if spec.get("press",false): press_visual = model(self,"press",Vector3(23,0,-1.1))
	if spec.get("water",false):
		water = MeshInstance3D.new()
		var water_mesh := BoxMesh.new()
		water_mesh.size = Vector3(16,.08,4.1)
		water.mesh = water_mesh
		water.position = Vector3(24,.1,0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(.10,.36,.40,.45)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = .15
		water.material_override = mat
		add_child(water)
		model(self,"tank",Vector3(18,0,-3),Vector3(1.4,1.2,1))
		model(self,"tank",Vector3(31,0,-3),Vector3(1.4,1.2,1))
	if spec.has("hazards"):
		for x in [21.0,32.0]:
			var hazard = model(self,"pendulum" if spec.hazards == "pendulum" else "generator",Vector3(x,0,0))
			if hazard: hazards.append(hazard)
			var signal_light := OmniLight3D.new()
			signal_light.position = Vector3(x,1.8,1)
			signal_light.omni_range = 3
			signal_light.light_energy = 2
			add_child(signal_light)
			danger_lights.append(signal_light)
	if spec.get("bridges",false):
		for x in [16,25,34]: model(self,"winch",Vector3(x,1,-1.8))
	speaker = AudioStreamPlayer3D.new()
	speaker.max_distance = 18
	add_child(speaker)

func met(expression: String) -> bool:
	if "&" in expression:
		for term in expression.split("&"):
			if not met(term): return false
		return true
	var parts := expression.split(":")
	var object = objects.get(parts[0])
	if object == null: return false
	if parts.size() == 2: return object.state == int(parts[1])
	return object.has_method("satisfied") and object.satisfied()

func all_met(expressions: Array) -> bool:
	for expression in expressions:
		if not met(str(expression)): return false
	return true

func feedback(sound: String) -> void:
	var path := "res://assets/audio/expansion/" + sound + ".ogg"
	if ResourceLoader.exists(path):
		speaker.stream = load(path)
		speaker.global_position = chapter.player.global_position
		speaker.play()

func _physics_process(delta: float) -> void:
	if chapter == null or not chapter.playing or chapter.respawning: return
	if absf(chapter.player.global_position.x-global_position.x-23) > 58: return
	phase += delta
	for object in objects.values():
		if object.has_method("update"): object.update(delta)
	if all_met(spec.goal): completed = true
	gate.position.y = move_toward(gate.position.y,6.3 if completed else 2.0,delta*3)
	if lift:
		# Autonomous round trip allows a carried object to return without operating a switch.
		var powered := met(str(spec.lift))
		var target := 3.11 if powered and fmod(phase,12) >= 5 and fmod(phase,12) < 10 else -.09
		if target < lift.position.y:
			for body in [chapter.player] + objects.values():
				if body is CharacterBody3D and absf(body.global_position.x-lift.global_position.x) < 2.45 and absf(body.global_position.z-lift.global_position.z) < 2:
					if body.global_position.y < lift.global_position.y-.2:
						target = maxf(target,body.global_position.y-global_position.y+1.5)
		lift.position.y = move_toward(lift.position.y,target,delta*1.35)
	if ladder:
		if local_player().y > 2.8 and local_player().x > 24: ladder_unlocked = true
		var unlocked := ladder_unlocked and (not spec.has("ladder_lock") or met(str(spec.ladder_lock)))
		if unlocked and not ladder.is_in_group("puzzle_interactable"): ladder.add_to_group("puzzle_interactable")
		if not unlocked: ladder.remove_from_group("puzzle_interactable")
		ladder.visible = unlocked
	if spec.get("belt",false) and objects.has("crate"):
		var crate = objects.crate
		if crate.position.x >= 11 and crate.position.x <= 28 and crate.handler == null:
			var direction := 1 if objects.belt.state == 1 else (-1 if objects.belt.state == 2 else 0)
			if not met("cargo_plate"): crate.move_and_collide(Vector3(direction*delta*1.3,0,0))
	if water:
		var wet := not met("drain") if index == 0 else (met("fill") or met("transfer:1") or met("pressure:1"))
		water.position.y = move_toward(water.position.y,1.9 if wet else -.05,delta*.6)
		if index == 0 and not met("drain") and local_player().x > 18 and local_player().x < 31: chapter.fail()
	if theme == "workshop" and index == 0:
		update_fuse_presence()
	if bridge_bodies.size() == 3:
		var raised := [met("winch_a") or met("pin_a"),met("winch_b") or met("pin_b"),met("pin_b")]
		for i in 3:
			bridge_bodies[i].position.y = move_toward(bridge_bodies[i].position.y,-.15 if raised[i] else -3.0,delta*2)
	if press_visual:
		var ram = press_visual.find_child("Ram",true,false)
		if ram and met("power:1"): ram.position.y = -.9 if met("limiter") else -.8 + sin(phase*3)*.8
	if spec.get("press",false) and met("power:1") and not met("limiter"):
		if absf(local_player().x-23) < 1.0: chapter.fail()
	for i in range(hazards.size()):
		var stopped := met("brake_a") if i == 0 else met("brake_b")
		var danger := not stopped and fmod(phase+float(i)*1.4,4.0) < 2.0
		if spec.get("hazards","") == "steam" and not met("timing:2"): danger = true
		danger_lights[i].light_color = Color(1,.17,.03) if danger else Color(.2,.9,.72)
		var pivot = hazards[i].find_child("Pendulum",true,false)
		if pivot: pivot.rotation.z = 0 if stopped else sin(phase*1.6+i)*.85
		if danger and absf(local_player().x-(21 if i == 0 else 32)) < .65: chapter.fail()
	update_guidance(delta)

func local_player() -> Vector3:
	return to_local(chapter.player.global_position)

func stage_objective() -> String:
	return preload("res://scripts/puzzles/room_guidance.gd").objective(self, chapter.player)

func update_guidance(delta: float) -> void:
	if is_instance_valid(presentation): presentation.update(delta)
	var next_text := stage_objective()
	if next_text != guidance_text:
		guidance_text = next_text
		guidance_changed.emit()

func update_fuse_presence() -> void:
	if theme != "workshop" or index != 0: return
	var fuse = objects.fuse
	fuse_revealed = fuse_revealed or objects.crate.position.x < 5.0 or fuse.held or not fuse.socket_id.is_empty()
	fuse.set_concealed(not fuse_revealed)

func capture_state() -> Dictionary:
	var states := {}
	for id in objects:
		states[id] = objects[id].capture_state()
	return {"objects":states,"completed":completed,"ladder_unlocked":ladder_unlocked,"fuse_revealed":fuse_revealed,"phase":phase,"lift_y":lift.position.y if lift else 0.0,"water_y":water.position.y if water else 0.0,"bridge_y":bridge_bodies.map(func(body): return body.position.y)}

func restore_state(data: Dictionary) -> void:
	completed = bool(data.get("completed",false))
	ladder_unlocked = bool(data.get("ladder_unlocked",false))
	fuse_revealed = bool(data.get("fuse_revealed",false))
	phase = float(data.get("phase",0))
	var states: Dictionary = data.get("objects",{})
	for id in objects:
		objects[id].restore_state(states.get(id,initial.get("objects",{}).get(id,{})))
	for object in objects.values():
		if object is CharacterBody3D and "socket_id" in object and not object.socket_id.is_empty():
			var socket = objects.get(object.socket_id)
			if socket:
				object.attach_to_socket(socket)
				socket.occupied = object
	if theme == "workshop" and index == 0 and not data.has("fuse_revealed"):
		var fuse = objects.fuse
		# Old saves used z=.5; ordinary settling on the floor is not discovery.
		var at_original_spot: bool = absf(fuse.position.x - 8.2) < .02 and fuse.position.y < .12 and (absf(fuse.position.z - .5) < .02 or absf(fuse.position.z - 1.05) < .02)
		fuse_revealed = not at_original_spot
		if at_original_spot and fuse.socket_id.is_empty(): fuse.position.z = 1.05
	update_fuse_presence()
	gate.position.y = 6.3 if completed else 2.0
	if lift: lift.position.y = float(data.get("lift_y",-.09))
	if water: water.position.y = float(data.get("water_y",.1))
	var heights: Array = data.get("bridge_y",[])
	for i in range(bridge_bodies.size()):
		bridge_bodies[i].position.y = float(heights[i]) if i < heights.size() else -3.0
	guidance_text = ""
	if is_instance_valid(presentation): presentation.update(0)

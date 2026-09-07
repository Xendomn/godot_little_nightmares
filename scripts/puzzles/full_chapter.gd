extends Node3D
signal checkpoint_reached(id: String)
signal level_completed
@export var level_id := "workshop"
const CONTENT = preload("res://scripts/puzzles/campaign_content.gd")
const ROOM = preload("res://scripts/puzzles/puzzle_room.gd")
var managed := false
var playing := false
var respawning := false
var checkpoint_id := "room_1"
var active_room := 0
var rooms: Array = []
var saved_snapshot: Dictionary = {}
var player: CharacterBody3D
var keeper: CharacterBody3D
var camera: Camera3D
var ui: CanvasLayer
var world: Node3D
var sounds: Node
var transition: Tween
var play_time := 0.0
var chase_room := -1

func _ready() -> void:
	preload("res://scripts/input_setup.gd").configure()
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	var content := CONTENT.rooms(level_id)
	for i in range(content.size()):
		var room = load("res://scenes/chapters/full/"+level_id+"/room_"+str(i+1)+".tscn").instantiate()
		room.name = "Room"+str(i+1)
		room.theme = level_id
		room.index = i
		room.chapter = self
		room.position.x = i*46
		world.add_child(room)
		rooms.append(room)
		room.guidance_changed.connect(func():
			if room == rooms[active_room] and is_instance_valid(ui): refresh_objective())
	player = load("res://scenes/actors/player.tscn").instantiate()
	player.name = "Player"
	player.extended_interactions = true
	var original_visual = player.get_node("Visual")
	var visual_transform: Transform3D = original_visual.transform
	player.remove_child(original_visual)
	original_visual.free()
	var visual = load("res://assets/models/expansion/doll_interactions.glb").instantiate()
	visual.name = "Visual"
	visual.transform = visual_transform
	player.add_child(visual)
	add_child(player)
	player.add_to_group("player")
	player.died.connect(fail)
	keeper = load("res://scenes/actors/keeper.tscn").instantiate()
	keeper.name = "Keeper"
	add_child(keeper)
	keeper.player = player
	keeper.active = false
	keeper.hide()
	keeper.caught.connect(fail)
	camera = load("res://scenes/actors/camera.tscn").instantiate()
	camera.name = "Camera"
	add_child(camera)
	camera.player = player
	camera.min_x = 6
	camera.max_x = 271
	camera.follow_height = true
	ui = load("res://scenes/actors/interface.tscn").instantiate()
	ui.name = "Interface"
	add_child(ui)
	sounds = load("res://scenes/actors/soundscape.tscn").instantiate()
	sounds.name = "Soundscape"
	add_child(sounds)
	player.footstep.connect(func(): sounds.play_effect("step",player.crouching))
	ui.resume_requested.connect(toggle_pause)
	if not managed:
		ui.start_requested.connect(start_game)
		ui.restart_requested.connect(start_game)
	ui.quit_requested.connect(func(): get_tree().quit())
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.023,.035,.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.3,.44,.5)
	env.ambient_light_energy = .55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(.06,.1,.12)
	env.fog_density = .009
	environment.environment = env
	add_child(environment)
	refresh()
	player.enabled = false

func start_game() -> void:
	if transition and transition.is_valid(): transition.kill()
	get_tree().paused = false
	playing = true
	respawning = false
	ui.begin()
	ui.fade.color.a = 0
	restore_checkpoint("room_1")

func checkpoint(id: String) -> void:
	if CONTENT.CHECKPOINTS.find(id) <= CONTENT.CHECKPOINTS.find(checkpoint_id): return
	checkpoint_id = id
	saved_snapshot = capture_world()
	checkpoint_reached.emit(id)
	ui.notice("线结已系好 · 检查点已保存",2)

func capture_world() -> Dictionary:
	var state := {}
	for i in range(rooms.size()): state[str(i)] = rooms[i].capture_state()
	var carrying: Array = []
	var held = player.get_node("Interactions").carried
	if held:
		for i in range(rooms.size()):
			for id in rooms[i].objects:
				if rooms[i].objects[id] == held: carrying = [i,str(id)]
	return {"rooms":state,"spawn":[player.position.x,player.position.y,player.position.z],"carrying":carrying}

func get_checkpoint_snapshot() -> Dictionary:
	return saved_snapshot.duplicate(true)

func restore_checkpoint(id, snapshot: Dictionary = {}) -> void:
	player.enabled = false
	keeper.active = false
	keeper.hide()
	chase_room = -1
	player.get_node("Interactions").cancel_interaction()
	checkpoint_id = str(id) if str(id) in CONTENT.CHECKPOINTS else "room_1"
	active_room = clampi(int(checkpoint_id.split("_")[1])-1,0,5)
	var states: Dictionary = snapshot.get("rooms",{})
	for i in range(rooms.size()):
		rooms[i].restore_state(states.get(str(i),rooms[i].initial))
		# A requested chapter entry needs no fabricated puzzle flags.
		if states.is_empty() and i < active_room:
			rooms[i].completed = true
			rooms[i].gate.position.y = 6.3
	var spawn := Vector3(active_room*46+2,.08,0)
	var values = snapshot.get("spawn",[])
	if values is Array and values.size() == 3: spawn = Vector3(float(values[0]),float(values[1]),float(values[2]))
	player.reset_to(spawn)
	player.enabled = playing and not respawning
	var carrying = snapshot.get("carrying",[])
	if carrying is Array and carrying.size() == 2 and int(carrying[0]) in range(rooms.size()):
		var held = rooms[int(carrying[0])].objects.get(str(carrying[1]))
		if held is CharacterBody3D and held.has_method("set_held"):
			held.detach_from_socket()
			held.set_held(true)
			held.global_position = player.global_position + Vector3(.48,.7,0)
			player.get_node("Interactions").carried = held
			player.get_node("Interactions").pickup_position = spawn+Vector3(-.9,.15,0)
	camera.instant = true
	saved_snapshot = capture_world()
	refresh()

func _process(delta: float) -> void:
	if not playing or respawning: return
	play_time += delta
	if player.velocity.y < -10.5:
		fail()
		return
	var next_room := clampi(int(player.position.x/46),0,5)
	if next_room > active_room and rooms[active_room].completed:
		active_room = next_room
		checkpoint("room_"+str(active_room+1))
		refresh()
	var room = rooms[active_room]
	if active_room in [2,4,5] and room.spec.has("mid") and room.met(str(room.spec.mid)):
		# Commit on stable ground; never save in a lift shaft or a temporary hazard.
		if player.is_on_floor() and player.position.y < .2:
			checkpoint("room_"+str(active_room+1)+"_mid")
	update_encounter(room,delta)
	ui.prompt.text = InputHints.format_text(player.get_node("Interactions").prompt_text)
	refresh_brake_status()
	if player.position.x > 274 and rooms[5].completed: finish_game()

func refresh() -> void:
	ui.chapter.text = CONTENT.TITLES[CONTENT.IDS.find(level_id)]+" · "+str(active_room+1)+" / 6 · "+rooms[active_room].spec.title
	refresh_objective()
	ui.set_puzzle_hints(level_id+"_"+str(active_room),rooms[active_room].spec.hints)

func refresh_objective() -> void:
	ui.objective.text = rooms[active_room].stage_objective()
	refresh_brake_status()

func refresh_brake_status() -> void:
	var timers := PackedStringArray()
	var expired := false
	for device in rooms[active_room].objects.values():
		if device.has_method("satisfied") and device.spec.kind == "brake":
			if device.timer > 0: timers.append(device.display_name() + "剩余 %.1f 秒" % device.timer)
			elif device.state > 0: expired = true
	ui.mechanism_status.text = "  ·  ".join(timers) if not timers.is_empty() else ("制动已结束 · 可返回制动杆重新启动" if expired else "")

func fail() -> void:
	if not playing or respawning: return
	respawning = true
	player.enabled = false
	keeper.active = false
	transition = create_tween()
	transition.tween_property(ui.fade,"color:a",1.0,.25)
	transition.tween_callback(func(): restore_checkpoint(checkpoint_id,saved_snapshot))
	transition.tween_property(ui.fade,"color:a",0.0,.3)
	transition.tween_callback(func():
		respawning = false
		player.enabled = playing)

func toggle_pause() -> void:
	if playing and not respawning:
		get_tree().paused = not get_tree().paused
		ui.set_pause(get_tree().paused)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not InputHints.blocked.has("pause"):
		toggle_pause()

func finish_game() -> void:
	if not playing: return
	playing = false
	player.enabled = false
	keeper.active = false
	level_completed.emit()
	if not managed: ui.ending.show()

func update_encounter(room: Node3D, delta: float) -> void:
	if not room.spec.get("chase",false):
		keeper.active = false
		keeper.hide()
		return
	var local_x: float = room.local_player().x
	var ended: bool = room.met("barrier") if level_id == "workshop" else room.met("quiet_gate")
	if ended:
		keeper.active = false
		keeper.visual_driver.play("stumble")
		ui.threat.text = ""
		return
	if chase_room != active_room and local_x > (12 if level_id == "workshop" else 17):
		chase_room = active_room
		keeper.position = Vector3(room.position.x+3,.05,0)
		keeper.finale = true
		keeper.use_original_passage = false
		keeper.chase_speed = 1.9 if level_id == "workshop" else 1.2
		keeper.grace = 2
		keeper.active = true
		keeper.show()
	if keeper.active:
		# The reverse belt physically slows the pursuit lane. Vault's bell holds
		# the keeper at the bell while the player reaches the cargo basket.
		if level_id == "workshop" and room.met("belt:2"):
			keeper.chase_speed = 1.35
		elif level_id == "thread_vault" and room.met("bell") and keeper.position.x > room.position.x+9:
			keeper.position.x = room.position.x+9
			keeper.visual_driver.play("listen",delta*2)
		ui.threat.text = "脚步正在靠近……"
		sounds.desired_mix = .75

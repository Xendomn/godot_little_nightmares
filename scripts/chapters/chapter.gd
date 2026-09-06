extends Node3D

signal checkpoint_reached(id: int)
signal level_completed
@export var level_id: String = "laundry"
var managed := false
var rules: RefCounted
var flags: Dictionary = {}
var playing := false
var respawning := false
var nearest: Node3D
var transition: Tween
var play_time := 0.0
var checkpoints: Array[Vector3] = []
@onready var player = $Player
@onready var keeper = $Keeper
@onready var camera = $Camera
@onready var ui = $Interface
@onready var sounds = $Soundscape
@onready var world = $World

func _ready() -> void:
	preload("res://scripts/input_setup.gd").configure()
	rules = preload("res://scripts/chapters/chapter_rules.gd").new(level_id)
	flags = rules.flags
	var definition = load("res://resources/levels/" + level_id + ".tres")
	checkpoints = definition.checkpoint_positions
	camera.min_x = definition.camera_min
	camera.max_x = definition.camera_max
	camera.follow_height = true
	camera.player = player
	player.add_to_group("player")
	player.died.connect(fail)
	player.footstep.connect(func(): sounds.play_effect("step", player.crouching))
	keeper.player = player
	keeper.caught.connect(fail)
	keeper.use_original_passage = false
	if level_id == "clocktower":
		keeper.pursuit_depth = -1.5
	var patrol := {"laundry": Vector3(36, 47, 2.6), "thread_vault": Vector3(44, 55, 0), "clocktower": Vector3(35, 69, 2.6)}
	var bounds: Vector3 = patrol[level_id]
	keeper.patrol_min = bounds.x
	keeper.patrol_max = bounds.y
	keeper.zone_min = bounds.x - 2
	keeper.zone_max = bounds.y + 2
	keeper.start_position = Vector3(bounds.y, bounds.z + 0.05, -1.3)
	keeper.reset_keeper()
	for item in world.get_children():
		if item.has_signal("used"):
			item.chapter = self
			item.used.connect(use_mechanism)
		if item.has_method("reset_crate"):
			item.player = player
	if not managed:
		ui.start_requested.connect(start_game)
		ui.restart_requested.connect(start_game)
	ui.resume_requested.connect(toggle_pause)
	ui.quit_requested.connect(func(): get_tree().quit())
	refresh()
	set_hazard_processing(false)

func start_game() -> void:
	if transition and transition.is_valid():
		transition.kill()
	get_tree().paused = false
	playing = true
	respawning = false
	play_time = 0
	ui.begin()
	ui.fade.color.a = 0
	restore_checkpoint(0)
	ui.notice({"laundry": "水声盖不住每一个脚步。", "thread_vault": "听见铃声时，他会忘记你一小会儿。", "clocktower": "天亮之前，让最后一口钟醒来。"}[level_id], 5)

func mechanism_available(id: String) -> bool:
	if id in ["fill", "wind"] and (player.position.x < 23.3 or player.position.x > 26.7):
		return false
	if id == "fill" and absf(world.get_node("PushCrate").position.x - 25) >= 0.65:
		return false
	return rules.available(id)

func use_mechanism(id: String) -> void:
	if not rules.activate(id):
		return
	player.visual_driver.play("interact", 0.5)
	sounds.play_effect("switch")
	match id:
		"drain":
			ui.notice("水退了。前面的洗衣车能压住升降台。")
		"fill", "wind":
			world.get_node("Lift").activate()
			ui.notice("站稳。升降台正在上升。")
		"counterweight":
			world.get_node("Bridge0").activate()
			ui.notice("配重拉下了踏板。沿着灯光寻找绞盘。")
		"winch_a":
			world.get_node("Bridge1").activate()
		"winch_b":
			world.get_node("Bridge2").activate()
		"bell":
			keeper.distract(Vector3(41, 0, -1.3), 16)
			sounds.play_effect("pickup")
			ui.notice("铃声会把他引到左边。蹲下，从桌底过去。", 4)
		"brake":
			for hazard in hazards():
				hazard.suppressed = 8
			ui.notice("摆锤停住八秒。现在穿过！", 3)
		"release":
			begin_chase()
			ui.notice("钟响了。奔向晨光！  {run} 奔跑", 4)
	refresh()

func begin_chase() -> void:
	keeper.reset_keeper()
	keeper.position = Vector3(29, 2.65, -1.3)
	keeper.mode = keeper.Mode.CHASE
	keeper.suspicion = 1
	keeper.grace = 3
	keeper.active = true
	camera.chase = true

func hazards() -> Array:
	return world.get_children().filter(func(node): return node.has_method("reset_hazard"))

func set_hazard_processing(value: bool) -> void:
	for hazard in hazards():
		hazard.set_physics_process(value)

func _process(delta: float) -> void:
	if not playing or respawning:
		return
	play_time += delta
	var x: float = player.position.x
	match level_id:
		"laundry":
			if flags.get("drain", false) and x > 17:
				checkpoint(1)
			if world.has_node("PushCrate") and absf(world.get_node("PushCrate").position.x - 25) < 0.65 and not flags.get("cart_ready", false):
				use_mechanism("cart_ready")
			if flags.get("fill", false) and x > 30 and player.position.y > 2.3:
				checkpoint(2)
			keeper.active = x > 33 and x < 51
		"thread_vault":
			if absf(world.get_node("PushCrate").position.x - 10) < 0.55 and not flags.get("counterweight", false):
				use_mechanism("counterweight")
			if flags.get("counterweight", false) and x > 17:
				checkpoint(1)
			if flags.get("winch_b", false) and x > 39:
				checkpoint(2)
			keeper.active = x > 40 and x < 59
		"clocktower":
			if x > 39:
				player.position.z = maxf(player.position.z, -0.65)
			if x > 17 and not flags.get("brake_crossed", false):
				use_mechanism("brake_crossed")
				checkpoint(1)
			if flags.get("release", false):
				if x > 34:
					checkpoint(2)
				keeper.active = true
				keeper.mode = keeper.Mode.CHASE
				keeper.suspicion = 1
				keeper.last_seen = Vector3(player.position.x, 2.6, -1.3)
				keeper.lost_time = 0
				# The keeper uses the back maintenance ledge, clear of jumps and the low duct.
				keeper.patrol_depth = -1.3
				keeper.chase_speed = 3.25
	update_prompt()
	sounds.desired_mix = 1.0 if keeper.active and keeper.mode == keeper.Mode.CHASE else 0.15
	ui.threat.text = "快跑！" if keeper.active and keeper.mode == keeper.Mode.CHASE else ("他在听……" if keeper.active and keeper.mode == keeper.Mode.ALERT else "")
	if x > (68 if level_id == "clocktower" else 61) and rules.checkpoint == 2:
		finish_game()

func checkpoint(id: int) -> void:
	if rules.checkpoint >= id:
		return
	rules.checkpoint = id
	checkpoint_reached.emit(id)
	ui.notice("线结已系好  ·  检查点已保存", 2.5)
	refresh()

func update_prompt() -> void:
	nearest = null
	var distance := 1.7
	for item in world.get_children():
		if not item.has_method("get_prompt") or not item.visible:
			continue
		if item.has_method("reset_crate"):
			if item.can_interact(player):
				nearest = item
			continue
		var d: float = (player.position + Vector3(0, 0.6, 0)).distance_to(item.position)
		if d < distance:
			var query := PhysicsRayQueryParameters3D.create(player.position + Vector3(0, 0.6, 0), item.position, 1)
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				continue
			nearest = item
			distance = d
	ui.prompt.text = InputHints.format_text(nearest.get_prompt()) if nearest else ""
	if nearest and InputHints.just_pressed("interact"):
		nearest.interact(player)

func refresh() -> void:
	ui.chapter.text = {"laundry": "02 / 染洗间", "thread_vault": "03 / 悬线库", "clocktower": "04 / 钟楼"}[level_id] + "  ·  " + str(rules.checkpoint + 1) + "/3"
	var objectives := {
		"laundry": ["转动排水阀，穿过积水槽", "将洗衣车推上黄框，再站上升降台拉灌水杆", "躲过缝纫师，等待蒸汽熄灭后通过"],
		"thread_vault": ["把线轴箱推上配重板，放下第一块踏板", "依次操作两处绞盘，连起悬桥", "摇铃引开守卫，沿桌底抵达出口"],
		"clocktower": ["拉下制动杆，在倒计时内穿过摆锤", "给升降台上弦，上楼释放钟锤", "跑、跳、蹲下，穿过最后一道晨光"]
	}
	ui.objective.text = objectives[level_id][rules.checkpoint]
	if level_id == "laundry":
		world.get_node("Water").visible = not flags.get("drain", false)
		world.get_node("WaterHazard").enabled = not flags.get("drain", false)

func restore_checkpoint(id: int) -> void:
	rules.restore(id)
	flags = rules.flags
	player.reset_to(checkpoints[rules.checkpoint])
	keeper.reset_keeper()
	camera.chase = false
	camera.instant = true
	for item in world.get_children():
		if item.has_method("reset_crate"):
			item.reset_crate()
		if item.has_method("reset_platform"):
			item.reset_platform()
		if item.has_method("reset_hazard"):
			item.reset_hazard()
	if level_id == "laundry" and id >= 2:
		world.get_node("Lift").activate(true)
		world.get_node("PushCrate").position = Vector3(25, 2.62, 0)
	if level_id == "thread_vault":
		if id >= 1:
			world.get_node("Bridge0").activate(true)
		if id >= 2:
			world.get_node("Bridge1").activate(true)
			world.get_node("Bridge2").activate(true)
	if level_id == "clocktower" and id >= 2:
		world.get_node("Lift").activate(true)
		begin_chase()
	player.enabled = playing and not respawning
	if respawning:
		keeper.active = false
	set_hazard_processing(playing and not respawning)
	refresh()

func get_checkpoint_snapshot() -> Dictionary:
	var canonical = preload("res://scripts/chapters/chapter_rules.gd").new(level_id)
	canonical.restore(rules.checkpoint)
	return canonical.flags.duplicate()

func fail() -> void:
	if not playing or respawning:
		return
	respawning = true
	player.enabled = false
	keeper.active = false
	set_hazard_processing(false)
	player.visual_driver.play("caught", 1)
	sounds.play_effect("caught")
	ui.notice("线还没有断。再试一次。", 2)
	transition = create_tween()
	transition.tween_property(ui.fade, "color:a", 1.0, 0.4)
	transition.tween_interval(0.65)
	transition.tween_callback(func(): restore_checkpoint(rules.checkpoint))
	transition.tween_property(ui.fade, "color:a", 0.0, 0.5)
	transition.tween_callback(func():
		respawning = false
		player.enabled = true
		set_hazard_processing(true))

func finish_game() -> void:
	playing = false
	player.enabled = false
	keeper.active = false
	set_hazard_processing(false)
	sounds.desired_mix = 0
	sounds.play_effect("win")
	ui.hud.hide()
	ui.notice("", 0)
	if level_id == "clocktower":
		transition = create_tween()
		transition.tween_property(player, "position:x", 71.0, 1.5)
		transition.tween_callback(func():
			ui.ending.show()
			level_completed.emit())
	else:
		level_completed.emit()
		if not managed:
			ui.ending.show()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not InputHints.blocked.has("pause") and playing and not respawning:
		toggle_pause()

func toggle_pause() -> void:
	if playing and not respawning:
		get_tree().paused = not get_tree().paused
		ui.set_pause(get_tree().paused)

extends Node3D

signal checkpoint_reached(id: int)
signal level_completed
var managed: bool = false

const Progress = preload("res://scripts/progress.gd")
var state = Progress.new()
var playing: bool = false
var respawning: bool = false
var chapter_index: int = 0
var play_time: float = 0
var nearest: Node3D
var low_hint_shown: bool = false
var transition: Tween
@onready var player = $Player
@onready var keeper = $Keeper
@onready var camera = $Camera
@onready var ui = $Interface
@onready var sounds = $Soundscape
@onready var crate = $World/PushCrate

func _ready() -> void:
	preload("res://scripts/input_setup.gd").configure()
	player.died.connect(fail)
	player.footstep.connect(func(): sounds.play_effect("step", player.crouching))
	keeper.player = player
	keeper.caught.connect(fail)
	camera.player = player
	crate.player = player
	for item in get_tree().get_nodes_in_group("interactables"):
		item.state = state
		item.used.connect(on_item_used)
	if not managed:
		ui.start_requested.connect(start_game)
		ui.restart_requested.connect(start_game)
	ui.resume_requested.connect(toggle_pause)
	ui.quit_requested.connect(func(): get_tree().quit())
	refresh_world()

func start_game() -> void:
	if transition and transition.is_valid():
		transition.kill()
	get_tree().paused = false
	state = Progress.new()
	for item in get_tree().get_nodes_in_group("interactables"):
		item.state = state
	chapter_index = 0
	play_time = 0
	playing = true
	respawning = false
	low_hint_shown = false
	player.reset_to(Vector3(2, 0.05, 0))
	crate.reset_crate()
	keeper.reset_keeper()
	camera.chase = false
	camera.instant = true
	ui.begin()
	ui.fade.color.a = 0
	ui.notice("有一盏灯，还在等你。", 4)
	refresh_world()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and playing and not respawning:
		toggle_pause()

func toggle_pause() -> void:
	if not playing or respawning:
		return
	get_tree().paused = not get_tree().paused
	ui.set_pause(get_tree().paused)

func _process(delta: float) -> void:
	if not playing or respawning:
		return
	play_time += delta
	var x: float = player.global_position.x
	if x > 24 and state.has_fuse and state.checkpoint < 1:
		state.enter_checkpoint(1)
		checkpoint_reached.emit(1)
		chapter_index = 1
		ui.notice("脚步轻一些。他还没有发现你。", 4)
		refresh_world()
	if x > 54 and state.power_on and state.checkpoint < 2:
		state.enter_checkpoint(2)
		checkpoint_reached.emit(2)
		chapter_index = 2
		ui.notice("别回头。  按住 Shift 奔跑", 4)
		refresh_world()
	keeper.active = x > 28 and player.enabled
	camera.chase = state.power_on
	sounds.desired_mix = 1.0 if state.power_on or keeper.mode == keeper.Mode.CHASE else keeper.suspicion * 0.5
	if x > 19 and not low_hint_shown:
		low_hint_shown = true
		ui.notice("低矮的地方，藏得下一个小小的你。  Ctrl 蹲伏", 4)
	if x > 86 and state.power_on:
		finish_game()
		return
	update_prompt()
	if crate.active:
		sounds.play_effect("push", true)
	ui.threat.text = "快跑！" if keeper.mode == keeper.Mode.CHASE and keeper.active else ("他在听……" if keeper.suspicion > 0.15 and keeper.active else "")

func update_prompt() -> void:
	nearest = null
	var distance := 1.7
	for item in get_tree().get_nodes_in_group("interactables"):
		if not item.visible:
			continue
		var d: float = (player.global_position + Vector3(0, 0.6, 0)).distance_to(item.global_position)
		if d < distance:
			var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 0.6, 0), item.global_position, 1)
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				continue
			distance = d
			nearest = item
	if crate.can_interact(player):
		nearest = crate
	ui.prompt.text = nearest.get_prompt() if nearest else ""
	if nearest and Input.is_action_just_pressed("interact"):
		nearest.interact(player)

func on_item_used(kind: String) -> void:
	player.visual_driver.play("pickup" if kind == "fuse" else "interact", 0.55)
	match kind:
		"fuse":
			sounds.play_effect("pickup")
			ui.notice("一枚温热的保险丝。前面的铁门松开了。")
		"panel":
			sounds.play_effect("switch")
			ui.notice("电路接通了。电闸在车间另一头。")
		"lever":
			sounds.play_effect("switch")
			keeper.reset_keeper(true)
			keeper.position = Vector3(player.position.x - 7.5, 0.05, -1.0)
			keeper.grace = 2
			keeper.active = true
			ui.notice("他醒了。跑向出货口！", 3)
	refresh_world()

func refresh_world() -> void:
	for item in get_tree().get_nodes_in_group("interactables"):
		item.refresh()
	set_gate($World/FuseGate, state.has_fuse or state.fuse_installed)
	set_gate($World/PowerGate, state.power_on)
	$World/PanelLamp.light_color = Color("66dfb7") if state.fuse_installed else Color("db6943")
	$World/ExitLamp.light_energy = 2.0 if state.power_on else 0.2
	$World/SwitchHandle.rotation.z = 0.6 if state.power_on else -0.4
	for surface in get_tree().get_nodes_in_group("conveyor_surfaces"):
		surface.material_override.set_shader_parameter("powered", 1.0 if state.power_on else 0.0)
	var titles := ["01 / 工作台下", "02 / 装配车间", "03 / 出货通道"]
	ui.chapter.text = titles[chapter_index]
	if state.power_on:
		ui.objective.text = "逃向尽头的投递滑槽"
	elif state.fuse_installed:
		ui.objective.text = "穿过车间，拉下远端电闸"
	elif state.has_fuse:
		ui.objective.text = "寻找配电箱 · 已携带保险丝"
	else:
		ui.objective.text = "推近积木箱，登上工作台寻找保险丝"

func set_gate(gate: Node3D, opened: bool) -> void:
	gate.visible = not opened
	for child in gate.get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", opened)

func fail() -> void:
	if respawning or not playing:
		return
	respawning = true
	player.enabled = false
	keeper.active = false
	player.visual_driver.play("caught", 1.0)
	sounds.play_effect("caught")
	ui.prompt.text = ""
	ui.notice("线还没有断。再试一次。", 2)
	transition = create_tween()
	transition.tween_property(ui.fade, "color:a", 1.0, 0.4)
	transition.tween_interval(0.65)
	transition.tween_callback(restore_world)
	transition.tween_property(ui.fade, "color:a", 0.0, 0.5)
	transition.tween_callback(func():
		respawning = false
		player.enabled = true)

func restore_world() -> void:
	state.restore_checkpoint()
	var spawns := [Vector3(2, 0.05, 0), Vector3(25, 0.05, 0), Vector3(55, 0.05, 0)]
	player.reset_to(spawns[state.checkpoint])
	player.enabled = not respawning
	crate.reset_crate()
	keeper.reset_keeper(state.power_on)
	camera.chase = state.power_on
	camera.instant = true
	chapter_index = state.checkpoint
	refresh_world()

func finish_game() -> void:
	playing = false
	state.completed = true
	player.enabled = false
	keeper.active = false
	sounds.desired_mix = 0
	sounds.play_effect("win")
	ui.hud.hide()
	ui.notice("", 0)
	transition = create_tween()
	transition.tween_property(player, "position", Vector3(89, -1.5, -1), 1.5)
	transition.parallel().tween_property(camera, "position:y", 6.5, 1.5)
	transition.tween_callback(func():
		if managed:
			level_completed.emit()
		else:
			ui.ending.show())

func get_checkpoint_snapshot() -> Dictionary:
	return {"has_fuse": state.checkpoint == 1, "power_on": state.checkpoint == 2}

func restore_checkpoint(id: int) -> void:
	state.checkpoint = clampi(id, 0, 2)
	restore_world()

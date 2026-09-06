extends CharacterBody3D

signal caught
enum Mode { PATROL, ALERT, CHASE, RETURN }
var mode: Mode = Mode.PATROL
var player: CharacterBody3D
var active: bool = false
var finale: bool = false
var facing: float = -1.0
var suspicion: float = 0.0
var lost_time: float = 0.0
var grace: float = 0.0
var gait: float = 0
var last_seen := Vector3.ZERO
var start_position := Vector3(46, 0.05, -1.3)
var patrol_target: float = 33.0
var passage_delay: float = 0
var passage_crossed: bool = false
var visual_driver: Node
var attack_time: float = 0
var attack_cooldown: float = 0
var patrol_min: float = 33
var patrol_max: float = 48
var patrol_depth: float = -1.3
var zone_min: float = 29
var zone_max: float = 53
var chase_speed: float = 3.45
var use_original_passage: bool = true
var distraction: float = 0
var distraction_position := Vector3.ZERO
var breath: AudioStreamPlayer3D
var heavy_step: AudioStreamPlayer3D
var cloth_rustle: AudioStreamPlayer3D
var step_time := 0.0

func _ready() -> void:
	visual_driver = preload("res://scripts/character_visual.gd").new()
	add_child(visual_driver)
	visual_driver.setup($Visual)
	breath = spatial_sound("keeper_breath", -10, true)
	heavy_step = spatial_sound("keeper_step", -2, false)
	cloth_rustle = spatial_sound("keeper_cloth", -8, false)

func spatial_sound(id: String, volume: float, looping: bool) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.name = id.to_pascal_case()
	var path := "res://assets/audio/" + id + ".wav"
	if ResourceLoader.exists(path):
		audio.stream = load(path).duplicate()
		if looping:
			audio.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			audio.stream.loop_end = int(audio.stream.get_length() * audio.stream.mix_rate)
	audio.volume_db = volume
	audio.unit_size = 3
	audio.max_distance = 14
	audio.position.y = 1.8 if looping else .2
	add_child(audio)
	return audio

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(player) or not player.enabled:
		if breath and breath.playing:
			breath.stop()
		return
	if breath and breath.stream and not breath.playing:
		breath.play()
	step_time -= delta
	if step_time <= 0 and mode != Mode.ALERT:
		step_time = .44 if mode == Mode.CHASE else .85
		heavy_step.play()
		cloth_rustle.play()
	grace = maxf(0, grace - delta)
	attack_cooldown = maxf(0, attack_cooldown - delta)
	if attack_time > 0:
		attack_time -= delta
		if attack_time <= 0 and global_position.distance_to(player.global_position) < 1.15 and has_clear_sight():
			active = false
			caught.emit()
		return
	if finale:
		mode = Mode.CHASE
		if use_original_passage and global_position.x >= 72.1 and not passage_crossed:
			passage_crossed = true
			passage_delay = 3.0
		if passage_delay > 0:
			passage_delay -= delta
			visual_driver.play("stumble")
			return
		# The tall keeper steps over conveyor gaps; its feet stay on the belt plane.
		var speed := chase_speed if global_position.x > player.global_position.x - 5.0 else chase_speed + 0.55
		global_position.x += speed * delta
		global_position.z = move_toward(global_position.z, player.global_position.z, delta * 1.1)
		if use_original_passage:
			global_position.y = 0
		facing = 1
	else:
		update_patrol(delta)
	if grace <= 0 and attack_cooldown <= 0 and global_position.distance_to(player.global_position) < 1.15 and has_clear_sight():
		attack_time = 0.35
		attack_cooldown = 1.1
		visual_driver.play("grab", 0.7)
	gait += delta * (10 if mode == Mode.CHASE else 4)
	$Visual.rotation.y = lerp_angle($Visual.rotation.y, facing * PI / 2, delta * 5)
	visual_driver.play("chase" if mode == Mode.CHASE else ("listen" if mode == Mode.ALERT else "walk"))
	if has_node("EyeLight"):
		$EyeLight.light_color = Color(1, 0.25, 0.12) if mode == Mode.CHASE else Color(1, 0.65, 0.3)

func can_see_player() -> bool:
	var offset := player.global_position - global_position
	var horizontal := Vector3(offset.x, 0, offset.z)
	if offset.length() > 6.0 or horizontal.normalized().dot(Vector3(facing, 0, 0)) < 0.35:
		return false
	return has_clear_sight()

func has_clear_sight() -> bool:
	var target := player.global_position + Vector3(0, 0.32 if player.crouching else 0.85, 0)
	var eye: Vector3 = visual_driver.head_position(global_position + Vector3(0.15 * facing, 2.8, 0)) if visual_driver else global_position + Vector3(0, 2.8, 0)
	var query := PhysicsRayQueryParameters3D.create(eye, target, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func update_patrol(delta: float) -> void:
	if distraction > 0:
		distraction -= delta
		mode = Mode.ALERT
		facing = signf(distraction_position.x - global_position.x)
		velocity = Vector3(facing * 1.2, velocity.y - 20 * delta, 0)
		if absf(distraction_position.x - global_position.x) < 0.4:
			velocity.x = 0
		move_and_slide()
		return
	var sees := can_see_player()
	var hears: bool = player.running and player.global_position.distance_to(global_position) < 3.6
	if sees or hears:
		last_seen = player.global_position
		lost_time = 0
		suspicion = minf(1.0, suspicion + delta * (1.3 if sees else 0.65))
		mode = Mode.CHASE if suspicion >= 1.0 else Mode.ALERT
	else:
		lost_time += delta
		suspicion = maxf(0, suspicion - delta * 0.55)
		if mode == Mode.CHASE and lost_time > 2.2:
			mode = Mode.RETURN
		elif mode == Mode.ALERT and suspicion <= 0:
			mode = Mode.PATROL
	var target := Vector3(patrol_target, start_position.y, patrol_depth)
	var speed := 1.05
	if mode == Mode.CHASE:
		target = last_seen
		speed = chase_speed
	elif mode == Mode.ALERT:
		target = global_position
		facing = signf(player.global_position.x - global_position.x)
	elif mode == Mode.RETURN:
		target = start_position
		if global_position.distance_to(target) < 0.4:
			mode = Mode.PATROL
	elif absf(global_position.x - patrol_target) < 0.3:
		patrol_target = patrol_max if patrol_target < (patrol_min + patrol_max) * 0.5 else patrol_min
	var direction := target - global_position
	direction.y = 0
	if direction.length() > 0.1:
		direction = direction.normalized()
		if absf(direction.x) > 0.05:
			facing = signf(direction.x)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y -= 20 * delta
	move_and_slide()
	# Follow the clear back aisle when a worktable blocks pursuit.
	if get_slide_collision_count() > 1 and mode == Mode.CHASE:
		global_position.z = move_toward(global_position.z, patrol_depth, delta)
	global_position.x = clampf(global_position.x, zone_min, zone_max)
	global_position.z = clampf(global_position.z, -1.5, 1.5)

func reset_keeper(chase_mode: bool = false) -> void:
	finale = chase_mode
	attack_time = 0
	attack_cooldown = 0
	distraction = 0
	passage_crossed = false
	passage_delay = 0
	position = Vector3(48.5, 0.05, 0) if finale else start_position
	velocity = Vector3.ZERO
	mode = Mode.CHASE if finale else Mode.PATROL
	suspicion = 0
	lost_time = 0
	grace = 2
	patrol_target = patrol_min
	facing = 1 if finale else -1
	active = false
	if visual_driver:
		visual_driver.reset_pose()

func distract(position_hint: Vector3, seconds: float = 6.0) -> void:
	distraction_position = position_hint
	distraction = seconds
	suspicion = 0
	lost_time = 0

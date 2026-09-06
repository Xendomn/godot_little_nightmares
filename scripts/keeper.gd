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

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(player) or not player.enabled:
		return
	grace = maxf(0, grace - delta)
	if finale:
		mode = Mode.CHASE
		if global_position.x >= 72.1 and not passage_crossed:
			passage_crossed = true
			passage_delay = 3.0
		if passage_delay > 0:
			passage_delay -= delta
			$Visual.rotation.z = sin(passage_delay * 19) * 0.07
			return
		# The tall keeper steps over conveyor gaps; its feet stay on the belt plane.
		var speed := 3.45 if global_position.x > player.global_position.x - 5.0 else 4.0
		global_position.x += speed * delta
		global_position.z = move_toward(global_position.z, player.global_position.z, delta * 1.1)
		global_position.y = 0
		facing = 1
	else:
		update_patrol(delta)
	if grace <= 0 and global_position.distance_to(player.global_position) < 0.85 and has_clear_sight():
		active = false
		caught.emit()
	gait += delta * (10 if mode == Mode.CHASE else 4)
	$Visual.rotation.y = lerp_angle($Visual.rotation.y, facing * 0.65, delta * 5)
	$Visual.rotation.z = sin(gait * 0.5) * 0.035
	for limb_name in ["ArmL", "ArmR", "LegL", "LegR"]:
		var limb = $Visual.find_child(limb_name, true, false)
		if limb:
			limb.rotation.z = sin(gait) * 0.24 * (1 if limb_name.ends_with("L") else -1)
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
	var eye := global_position + Vector3(0.15 * facing, 2.8, 0)
	var query := PhysicsRayQueryParameters3D.create(eye, target, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func update_patrol(delta: float) -> void:
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
	var target := Vector3(patrol_target, 0, -1.3)
	var speed := 1.05
	if mode == Mode.CHASE:
		target = last_seen
		speed = 3.3
	elif mode == Mode.ALERT:
		target = global_position
		facing = signf(player.global_position.x - global_position.x)
	elif mode == Mode.RETURN:
		target = Vector3(46, 0, -1.3)
		if global_position.distance_to(target) < 0.4:
			mode = Mode.PATROL
	elif absf(global_position.x - patrol_target) < 0.3:
		patrol_target = 48.0 if patrol_target < 40 else 33.0
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
		global_position.z = move_toward(global_position.z, -1.45, delta)
	global_position.x = clampf(global_position.x, 29, 53)
	global_position.z = clampf(global_position.z, -1.5, 1.5)

func reset_keeper(chase_mode: bool = false) -> void:
	finale = chase_mode
	passage_crossed = false
	passage_delay = 0
	position = Vector3(48.5, 0.05, 0) if finale else start_position
	velocity = Vector3.ZERO
	mode = Mode.CHASE if finale else Mode.PATROL
	suspicion = 0
	lost_time = 0
	grace = 2
	patrol_target = 33
	facing = 1 if finale else -1
	active = false

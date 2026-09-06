extends CharacterBody3D

signal died
signal footstep

const WALK_SPEED := 2.6
const RUN_SPEED := 4.6
const CROUCH_SPEED := 1.35
const GRAVITY := 20.0
const JUMP_SPEED := 7.2
var enabled: bool = false
var crouching: bool = false
var running: bool = false
var pushing: bool = false
var facing: float = 1.0
var coyote: float = 0.0
var jump_buffer: float = 0.0
var gait: float = 0.0
var step_timer: float = 0.0
var model: Node3D
var limbs: Dictionary = {}
@onready var collider: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	model = $Visual
	for part in ["ArmL", "ArmR", "LegL", "LegR", "Head"]:
		var found = model.find_child(part, true, false)
		if found:
			limbs[part] = found

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	var axis := Input.get_vector("left", "right", "depth_up", "depth_down")
	var wants_crouch := Input.is_action_pressed("crouch")
	if wants_crouch:
		crouching = true
	elif crouching:
		var shape := CapsuleShape3D.new()
		shape.radius = 0.25
		shape.height = 1.2
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, 0.62, 0))
		query.collision_mask = 1
		crouching = not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
	var cap = collider.shape as CapsuleShape3D
	cap.height = 0.64 if crouching else 1.2
	collider.position.y = 0.34 if crouching else 0.62
	running = Input.is_action_pressed("run") and not crouching and not pushing and axis.length() > 0.1
	var speed: float = CROUCH_SPEED if crouching else (RUN_SPEED if running else WALK_SPEED)
	if pushing:
		speed = 1.25
	velocity.x = move_toward(velocity.x, axis.x * speed, 18.0 * delta)
	velocity.z = move_toward(velocity.z, axis.y * speed * 0.7, 18.0 * delta)
	if absf(axis.x) > 0.05:
		facing = signf(axis.x)
	coyote = 0.12 if is_on_floor() else coyote - delta
	jump_buffer = 0.14 if Input.is_action_just_pressed("jump") else jump_buffer - delta
	if jump_buffer > 0 and coyote > 0 and not crouching and not pushing:
		velocity.y = JUMP_SPEED
		coyote = 0
		jump_buffer = 0
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	global_position.z = clampf(global_position.z, -1.6, 1.6)
	if global_position.y < -4:
		enabled = false
		died.emit()
	animate_doll(delta, axis.length())

func animate_doll(delta: float, movement: float) -> void:
	gait += delta * (14.0 if running else 9.0) * movement
	var wave := sin(gait) * movement
	model.rotation.y = lerp_angle(model.rotation.y, facing * 0.45, delta * 12)
	model.scale.y = lerpf(model.scale.y, 0.55 if crouching else 1.0, delta * 15)
	model.position.y = absf(wave) * 0.035 if is_on_floor() else 0.03
	for part in limbs:
		if part.begins_with("Leg"):
			limbs[part].rotation.z = (-0.48 * facing if not is_on_floor() else wave * 0.35) * (1 if part.ends_with("L") else -1)
		elif part.begins_with("Arm"):
			limbs[part].rotation.z = -0.85 * facing if pushing else ((0.5 * facing if not is_on_floor() else wave * 0.28) * (-1 if part.ends_with("L") else 1))
		elif part == "Head":
			limbs[part].rotation.z = sin(Time.get_ticks_msec() * 0.0015) * 0.025
	if is_on_floor() and movement > 0.15:
		step_timer -= delta
		if step_timer <= 0:
			step_timer = 0.3 if running else 0.46
			footstep.emit()

func reset_to(spawn: Vector3) -> void:
	global_position = spawn
	velocity = Vector3.ZERO
	coyote = 0
	jump_buffer = 0
	pushing = false
	crouching = false
	facing = 1
	enabled = true

extends CharacterBody3D

signal died
signal footstep

const WALK_SPEED := 2.6
const RUN_SPEED := 4.6
const CROUCH_SPEED := 1.35
const GRAVITY := 20.0
const JUMP_SPEED := 7.2
@export var extended_interactions: bool = false
var interactions: Node
var enabled: bool = false:
	set(value):
		enabled = value
		if not value and is_instance_valid(interactions):
			interactions.cancel_interaction()
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
var visual_driver: Node
@onready var collider: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	if extended_interactions:
		interactions = preload("res://scripts/puzzles/interaction_controller.gd").new()
		interactions.name = "Interactions"
		add_child(interactions)
	model = $Visual
	visual_driver = preload("res://scripts/character_visual.gd").new()
	add_child(visual_driver)
	visual_driver.setup(model)
	for part in ["ArmL", "ArmR", "LegL", "LegR", "Head"]:
		var found = model.find_child(part, true, false)
		if found:
			limbs[part] = found

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	if extended_interactions and interactions.tick(delta):
		return
	# move_and_collide on ladders does not update CharacterBody's floor state.
	var left_ladder: bool = extended_interactions and interactions.just_left_ladder
	if left_ladder: interactions.just_left_ladder = false
	var carrying: bool = extended_interactions and interactions.carried != null
	var axis := Input.get_vector("left", "right", "depth_up", "depth_down")
	var wants_crouch := InputHints.pressed("crouch")
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
	running = Input.is_action_pressed("run") and not crouching and not pushing and not carrying and axis.length() > 0.1
	var speed: float = CROUCH_SPEED if crouching else (RUN_SPEED if running else WALK_SPEED)
	if pushing:
		speed = 1.25
	velocity.x = move_toward(velocity.x, axis.x * speed, 18.0 * delta)
	velocity.z = move_toward(velocity.z, axis.y * speed * 0.7, 18.0 * delta)
	if absf(axis.x) > 0.05:
		facing = signf(axis.x)
	coyote = 0.12 if is_on_floor() else coyote - delta
	jump_buffer = 0.14 if InputHints.just_pressed("jump") else jump_buffer - delta
	if left_ladder:
		coyote = 0
		jump_buffer = 0
	if jump_buffer > 0 and coyote > 0 and not crouching and not pushing and not carrying:
		velocity.y = JUMP_SPEED
		coyote = 0
		jump_buffer = 0
	if left_ladder or not is_on_floor():
		velocity.y -= GRAVITY * delta
	var was_grounded := is_on_floor()
	move_and_slide()
	if not was_grounded and is_on_floor() and not crouching:
		visual_driver.play("land", 0.18)
	global_position.z = clampf(global_position.z, -1.6, 1.6)
	if global_position.y < -4:
		enabled = false
		died.emit()
	animate_doll(delta, axis.length())

func animate_doll(delta: float, movement: float) -> void:
	gait += delta * (14.0 if running else 9.0) * movement
	var wave := sin(gait) * movement
	model.rotation.y = lerp_angle(model.rotation.y, facing * PI / 2, delta * 12)
	if visual_driver.animator:
		model.scale = Vector3.ONE
		model.position.y = 0
		var interaction_clip := ""
		if extended_interactions and is_instance_valid(interactions):
			if is_instance_valid(interactions.ladder):
				interaction_clip = "climb"
			elif is_instance_valid(interactions.carried):
				interaction_clip = "carry_walk" if Vector2(velocity.x, velocity.z).length() > .15 else "carry_idle"
			elif is_instance_valid(interactions.pushed):
				facing = signf(interactions.pushed.global_position.x - global_position.x)
				if Input.get_axis("left", "right") * facing < -.05:
					interaction_clip = "pull"
		if not interaction_clip.is_empty() and visual_driver.clips.has(interaction_clip):
			visual_driver.play(interaction_clip)
		else:
			visual_driver.update_motion(Vector2(velocity.x, velocity.z).length(), is_on_floor(), crouching, pushing, velocity.y)
	if is_on_floor() and movement > 0.15:
		step_timer -= delta
		if step_timer <= 0:
			step_timer = 0.3 if running else 0.46
			footstep.emit()

func reset_to(spawn: Vector3) -> void:
	if is_instance_valid(interactions):
		interactions.cancel_interaction()
	global_position = spawn
	velocity = Vector3.ZERO
	coyote = 0
	jump_buffer = 0
	pushing = false
	crouching = false
	facing = 1
	if visual_driver:
		visual_driver.reset_pose()
	enabled = true

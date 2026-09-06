extends CharacterBody3D

@export var min_x: float = 3.5
@export var max_x: float = 9.75
@export var lane_z: float = 0
@export var display_name: String = "积木箱"

var player: CharacterBody3D
var active: bool = false
var original_position: Vector3

func _ready() -> void:
	original_position = position

func get_prompt() -> String:
	return "按住 E + A / D  推动" + display_name

func can_interact(actor: Node3D) -> bool:
	return absf(actor.global_position.x - global_position.x) < 1.2 and absf(actor.global_position.z - global_position.z) < 0.85 and actor.global_position.y < global_position.y + 0.4

func interact(_actor: Node3D) -> void:
	pass

func _physics_process(delta: float) -> void:
	active = is_instance_valid(player) and player.enabled and Input.is_action_pressed("interact") and can_interact(player)
	if is_instance_valid(player):
		player.pushing = active
	velocity.y -= 20 * delta
	velocity.x = 0
	if active:
		var direction := Input.get_axis("left", "right")
		# Push only toward the crate; never pull it through the actor.
		if direction * (global_position.x - player.global_position.x) > 0:
			velocity.x = direction * 1.25
	var requested_x := velocity.x
	var before_x := global_position.x
	move_and_slide()
	# Jolt can stop a flat box at a coplanar floor edge despite an upward floor
	# normal. Retry a blocked step slightly above the seam, only with clear space.
	if is_on_floor() and absf(requested_x) > 0.1 and absf(global_position.x - before_x) < 0.001:
		var lifted := global_transform
		lifted.origin.y += 0.04
		if not test_move(lifted, Vector3(requested_x * delta, 0, 0)):
			global_transform = lifted
			velocity = Vector3(requested_x, 0, 0)
			move_and_slide()
	global_position.x = clampf(global_position.x, min_x, max_x)
	global_position.z = lane_z

func reset_crate() -> void:
	position = original_position
	velocity = Vector3.ZERO

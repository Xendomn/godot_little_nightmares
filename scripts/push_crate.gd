extends CharacterBody3D

var player: CharacterBody3D
var active: bool = false
var original_position: Vector3

func _ready() -> void:
	original_position = position

func get_prompt() -> String:
	return "按住 E + A / D  推动积木箱"

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
	move_and_slide()
	global_position.x = clampf(global_position.x, 3.5, 9.75)
	global_position.z = 0

func reset_crate() -> void:
	position = original_position
	velocity = Vector3.ZERO

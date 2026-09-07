extends CharacterBody3D
@export var object_id: String = ""
@export var mass: float = 3.0
@export var min_x: float = -1000.0
@export var max_x: float = 1000.0
@export var lane_z: float = 0.0
@export var size := Vector3(1, 1, 1)
var handler: Node3D
func _ready() -> void:
	add_to_group("puzzle_interactable")
	collision_layer = 1
	collision_mask = 1
	if not get_node_or_null("CollisionShape3D"):
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		collision.position.y = size.y * .5
		add_child(collision)
func _physics_process(delta: float) -> void:
	if is_instance_valid(handler):
		return
	velocity.x = 0
	velocity.y -= 20 * delta
	move_and_slide()
func can_interact(actor: Node3D) -> bool:
	return actor.get_node("Interactions").carried == null and absf(actor.global_position.y - global_position.y) < 1.3
func get_prompt() -> String:
	return "按住 {interact} + {horizontal} · 推拉箱子"
func interact(actor: Node3D) -> void:
	actor.get_node("Interactions").begin_push(self)
func move_with_actor(actor: CharacterBody3D, direction: float, delta: float) -> void:
	var movement := Vector3(direction * 1.25 * delta, 0, 0)
	movement.x = clampf(global_position.x + movement.x, min_x, max_x) - global_position.x
	# Both shapes must fit before either moves, including when pulling toward a wall.
	add_collision_exception_with(actor)
	actor.add_collision_exception_with(self)
	if not test_move(global_transform, movement) and not actor.test_move(actor.global_transform, movement):
		move_and_collide(movement)
		actor.move_and_collide(movement)
	actor.remove_collision_exception_with(self)
	remove_collision_exception_with(actor)
	velocity = Vector3(0, velocity.y - 20 * delta, 0)
	move_and_slide()
func capture_state() -> Dictionary:
	return {"position": [global_position.x, global_position.y, global_position.z]}
func restore_state(state: Dictionary) -> void:
	handler = null
	velocity = Vector3.ZERO
	var p = state.get("position", [])
	if p is Array and p.size() == 3:
		global_position = Vector3(clampf(float(p[0]), min_x, max_x), float(p[1]), float(p[2]))

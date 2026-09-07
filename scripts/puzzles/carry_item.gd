extends CharacterBody3D
## Small reusable object. Room snapshot resolves socket_id after restoring objects.
@export var object_id: String = ""
@export var item_kind: String = "fuse"
@export var mass: float = 1.0
var socket_id: String = ""
var held := false
var socket: Node3D
var home_position := Vector3.ZERO
func _ready() -> void:
	add_to_group("puzzle_interactable")
	collision_layer = 1
	collision_mask = 1
	home_position = global_position
	if not get_node_or_null("CollisionShape3D"):
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = Vector3(.34, .34, .34)
		collision.shape = shape
		collision.position.y = .17
		add_child(collision)
func _physics_process(delta: float) -> void:
	if held:
		return
	if is_instance_valid(socket):
		global_position = socket.global_position
		return
	velocity.y -= 20.0 * delta
	move_and_slide()
	if global_position.y < -5:
		global_position = home_position
		velocity = Vector3.ZERO
func can_interact(actor: Node3D) -> bool:
	var controller = actor.get_node_or_null("Interactions")
	return not held and controller != null and controller.carried == null
func interact(actor: Node3D) -> void:
	actor.get_node("Interactions").pickup(self)
func get_prompt() -> String:
	var names := {"fuse":"保险丝", "gear":"齿轮", "weight":"砝码", "wheel":"手轮"}
	return "{interact} · 拾取" + str(names.get(item_kind,"物品"))
func set_held(value: bool) -> void:
	held = value
	collision_layer = 0 if held else 1
	collision_mask = 0 if held else 1
	velocity = Vector3.ZERO
func attach_to_socket(target: Node3D) -> void:
	socket = target
	socket_id = str(target.get("object_id")) if "object_id" in target else str(target.name)
	set_held(false)
	collision_layer = 0
	collision_mask = 0
	global_position = target.global_position
func detach_from_socket() -> void:
	socket = null
	socket_id = ""
	set_held(false)
func capture_state() -> Dictionary:
	return {"position": [global_position.x, global_position.y, global_position.z], "socket_id": socket_id}
func restore_state(state: Dictionary) -> void:
	detach_from_socket()
	var p = state.get("position", [])
	if p is Array and p.size() == 3:
		global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	socket_id = str(state.get("socket_id", ""))

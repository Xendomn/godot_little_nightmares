extends Node3D
@export var object_id: String = ""
@export var height: float = 3.0
func _ready() -> void:
	add_to_group("puzzle_interactable")
func interaction_position(actor: Node3D) -> Vector3:
	return Vector3(global_position.x, clampf(actor.global_position.y + .6, global_position.y, global_position.y + height), global_position.z)
func can_interact(actor: Node3D) -> bool:
	return actor.get_node("Interactions").carried == null
func interact(actor: Node3D) -> void:
	actor.get_node("Interactions").attach_ladder(self)
func get_prompt() -> String:
	return "{interact} · Climb ladder"
func capture_state() -> Dictionary:
	return {}
func restore_state(_state: Dictionary) -> void:
	pass

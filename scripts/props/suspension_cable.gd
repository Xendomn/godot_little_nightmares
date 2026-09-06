extends Node3D
@export var target_path: NodePath
@export var attachment := Vector3.ZERO
@export var ceiling_y := 8.0
var target: Node3D
func _ready() -> void:
	target = get_node(target_path)
	update_cable()
func _process(_delta: float) -> void:
	update_cable()
func update_cable() -> void:
	var bottom := target.global_position + attachment
	global_position = Vector3(bottom.x, (bottom.y + ceiling_y) * .5, bottom.z)
	scale.y = maxf(.01, ceiling_y - bottom.y)

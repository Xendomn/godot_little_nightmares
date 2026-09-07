extends Node
## Fade only camera-side decoration; structural collision remains solid.
var player: Node3D
var meshes: Array[MeshInstance3D] = []
var transparency := 0.0
func _ready() -> void:
	for mesh in get_parent().find_children("*","MeshInstance3D",true,false):
		if mesh.global_position.z > 1.5: meshes.append(mesh)
func _process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
		if not player: return
	var distance := absf(player.global_position.x-get_parent().global_position.x)
	var target := .90 if distance < 1.6 else 0.0
	var next := move_toward(transparency,target,delta*5)
	if is_equal_approx(transparency,next): return
	transparency = next
	for mesh in meshes: mesh.transparency = transparency

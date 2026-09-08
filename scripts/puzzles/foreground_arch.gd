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
	var room = get_parent().get_parent()
	var camera := get_viewport().get_camera_3d()
	if camera and room.get("objects") is Dictionary:
		for object in room.objects.values():
			if not object.has_method("set_held") or object.held or is_instance_valid(object.socket) or not object.visible: continue
			if absf(object.global_position.x-player.global_position.x) > 6 or absf(object.global_position.y-player.global_position.y) > 1.6: continue
			var focus: Vector3 = object.global_position + Vector3(0,.25,0)
			if camera.is_position_behind(focus): continue
			for mesh in meshes:
				var inverse := mesh.global_transform.affine_inverse()
				if mesh.get_aabb().intersects_segment(inverse * camera.global_position, inverse * focus) != null:
					target = .90
					break
	var next := move_toward(transparency,target,delta*5)
	if is_equal_approx(transparency,next): return
	transparency = next
	for mesh in meshes: mesh.transparency = transparency

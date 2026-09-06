extends Camera3D

var player: Node3D
var chase: bool = false
var instant: bool = true

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var px: float = player.global_position.x
	var target := Vector3(clampf(px + (2.3 if chase else 1.5), 6.0, 84.0), 4.8, 11.8)
	if chase:
		target += Vector3(0, 0.8, 2.5)
	position = target if instant else position.lerp(target, 1.0 - exp(-delta * 3.0))
	instant = false
	look_at(Vector3(position.x, 1.45, -0.5), Vector3.UP)
	fov = lerpf(fov, 58.0 if chase else 52.0, delta * 2)

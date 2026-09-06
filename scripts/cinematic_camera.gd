extends Camera3D

var player: Node3D
var chase: bool = false
var instant: bool = true
var min_x: float = 6
var max_x: float = 84
var height_offset: float = 0
var follow_height: bool = false

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var px: float = player.global_position.x
	var vertical: float = maxf(0, player.global_position.y) if follow_height else height_offset
	var target := Vector3(clampf(px + (2.3 if chase else 1.5), min_x, max_x), 4.8 + vertical, 11.8)
	if chase:
		target += Vector3(0, 0.8, 2.5)
	position = target if instant else position.lerp(target, 1.0 - exp(-delta * 3.0))
	instant = false
	look_at(Vector3(position.x, position.y - (4.8 - 1.45) - (0.8 if chase else 0), -0.5), Vector3.UP)
	fov = lerpf(fov, 58.0 if chase else 52.0, delta * 2)

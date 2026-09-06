extends Node3D
var origin_y := 0.0
var drained := false
var progress := 0.0
func _ready() -> void:
	origin_y = position.y
func set_drained(value: bool, immediate: bool = false) -> void:
	drained = value
	if immediate:
		progress = 1.0 if value else 0.0
		update_surface()
func _process(delta: float) -> void:
	progress = move_toward(progress, 1.0 if drained else 0.0, delta / .9)
	update_surface()
func update_surface() -> void:
	position.y = origin_y - progress * .45
	visible = progress < 1

extends AnimatableBody3D

@export var travel: Vector3 = Vector3(0, 2.6, 0)
@export var duration: float = 3.0
var origin: Vector3
var target: Vector3
var active: bool = false
var progress: float = 0

func _ready() -> void:
	origin = position
	target = origin
	sync_to_physics = true

func activate(immediate: bool = false) -> void:
	active = true
	target = origin + travel
	if immediate:
		sync_to_physics = false
		position = target
		sync_to_physics = true
		progress = 1

func reset_platform() -> void:
	active = false
	progress = 0
	sync_to_physics = false
	position = origin
	sync_to_physics = true
	target = origin

func _physics_process(delta: float) -> void:
	if active and progress < 1:
		progress = minf(1.0, progress + delta / maxf(0.1, duration))
		position = origin.lerp(target, smoothstep(0, 1, progress))

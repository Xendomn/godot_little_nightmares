extends Area3D

@export var period: float = 5.0
@export var active_duration: float = 2.0
@export var phase_offset: float = 0
@export var caption: String = "STEAM"
var time: float = 0
var suppressed: float = 0
var enabled: bool = true
var dangerous: bool = false

func _physics_process(delta: float) -> void:
	time += delta
	suppressed = maxf(0, suppressed - delta)
	var phase := fmod(time + phase_offset, period)
	dangerous = enabled and suppressed <= 0 and phase < active_duration
	if has_node("Warning"):
		$Warning.visible = dangerous
	if has_node("Caption"):
		$Caption.text = caption + (" !" if dangerous else "  " + str(ceili(suppressed if suppressed > 0 else period - phase)))
	if has_node("PendulumPivot"):
		$PendulumPivot.rotation.z = sin(phase / period * TAU) * .75 if suppressed <= 0 else .9
	if dangerous:
		for body in get_overlapping_bodies():
			if body.is_in_group("player") and body.enabled:
				body.enabled = false
				body.died.emit()

func reset_hazard() -> void:
	time = 0
	suppressed = 0
	dangerous = false

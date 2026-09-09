extends RefCounted
## One clock drives visible pose, prewarning and contact bounds.
var time := 0.0
func advance(delta: float, stopped: bool) -> void:
	if not stopped: time += maxf(delta,0)
func angle() -> float:
	return cos(time * TAU / 20.0) * .95
func bob_position() -> Vector3:
	return Vector3(sin(angle()) * 2.6,4.1-cos(angle())*2.6,0)
func pendulum_stage() -> String:
	if absf(angle()) < .28: return "active"
	if absf(angle()) < .8: return "warning"
	return "safe"
func hits_pendulum(point: Vector3, body_height: float = 1.24) -> bool:
	var bob := bob_position()
	return absf(point.x-bob.x)<.65 and absf(point.z)<1.95 and point.y< bob.y+.55 and point.y+body_height>bob.y-.55
func steam_stage() -> String:
	var phase := fposmod(time,9.0)
	if phase < 1.0: return "warning"
	return "active" if phase < 3.0 else "safe"
func capture_state() -> Dictionary:
	return {"time":time}
func restore_state(data: Dictionary) -> void:
	time = float(data.get("time",0))

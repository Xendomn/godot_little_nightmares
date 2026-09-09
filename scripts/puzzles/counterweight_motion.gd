extends RefCounted
## Guided cargo: mass changes the equilibrium stop; a pawl carries a locked load.
var height := -.09
var pinned := false
func target_height(mass: float) -> float:
	return -.09 + clampf(mass,0,2) * 1.6
func advance(delta: float, mass: float) -> void:
	if not pinned: height = move_toward(height,target_height(mass),maxf(delta,0)*1.1)
func lock() -> void:
	pinned = true
func capture_state() -> Dictionary:
	return {"height":height,"pinned":pinned}
func restore_state(data: Dictionary) -> void:
	height = clampf(float(data.get("height",-.09)),-.09,3.11)
	pinned = bool(data.get("pinned",false))

extends RefCounted
## Equal-area tanks; volumes are expressed as metres of water depth.
const CAPACITY := 1.9
const FLOW := .45
var left := 0.0
var right := 0.0
var vented := false
func fill(delta: float) -> void:
	left = minf(CAPACITY, left + maxf(delta, 0) * FLOW)
func drain(delta: float) -> void:
	left = maxf(0, left - maxf(delta, 0) * FLOW)
func transfer(delta: float, toward_left: bool) -> void:
	var source := right if toward_left else left
	var destination := left if toward_left else right
	var amount := minf(maxf(delta, 0) * FLOW, minf(source, CAPACITY - destination))
	left += amount if toward_left else -amount
	right += -amount if toward_left else amount
func pressure() -> float:
	return maxf(left - right, 0) / CAPACITY if vented else 0.0
func capture_state() -> Dictionary:
	return {"left":left,"right":right,"vented":vented}
func restore_state(data: Dictionary) -> void:
	left = clampf(float(data.get("left",0)),0,CAPACITY)
	right = clampf(float(data.get("right",0)),0,CAPACITY)
	vented = bool(data.get("vented",false))

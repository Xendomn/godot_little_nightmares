extends RefCounted
## Unwrapped angles avoid discontinuities at 0/TAU. 24s slow revolution.
const SPEED := TAU / 24.0
const TOLERANCE := PI / 12.0
var fast := 0.0
var slow := 0.0
var coupled := false
func advance(delta: float, powered: bool, fast_braked: bool, all_braked: bool = false) -> void:
	if not powered or all_braked or coupled: return
	slow += maxf(delta,0) * SPEED
	if not fast_braked: fast += maxf(delta,0) * SPEED * 2.0
func distance(a: float, b: float) -> float:
	return absf(wrapf(a-b,-PI,PI))
func aligned() -> bool:
	return distance(fast,slow) <= TOLERANCE
func at_mark(mark: int) -> bool:
	return distance(slow,float(mark)*PI*.5) <= TOLERANCE
func capture_state() -> Dictionary:
	return {"fast":fast,"slow":slow,"coupled":coupled}
func restore_state(data: Dictionary) -> void:
	fast = float(data.get("fast",0))
	slow = float(data.get("slow",0))
	coupled = bool(data.get("coupled",false))

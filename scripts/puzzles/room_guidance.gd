extends RefCounted
## Keep the goal visible; solutions live in voluntary hints and local feedback.

static func objective(room: Node3D, _actor: Node3D) -> String:
	if room.completed: return "通道已开启 · 沿亮起的引导向右前进"
	return str(room.spec.objective)

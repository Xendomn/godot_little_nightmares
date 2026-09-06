extends RefCounted

var level_id: String
var flags: Dictionary = {}
var checkpoint: int = 0

func _init(id: String = "laundry") -> void:
	level_id = id

func available(action: String) -> bool:
	if action in ["bell", "brake"]:
		return (action == "bell" and level_id == "thread_vault") or (action == "brake" and level_id == "clocktower")
	if flags.get(action, false):
		return false
	match level_id:
		"laundry":
			return action == "drain" or (action == "cart_ready" and flags.get("drain", false)) or (action == "fill" and flags.get("cart_ready", false))
		"thread_vault":
			return action == "counterweight" or (action == "winch_a" and flags.get("counterweight", false)) or (action == "winch_b" and flags.get("winch_a", false))
		"clocktower":
			return action == "brake_crossed" or (action == "wind" and flags.get("brake_crossed", false)) or (action == "release" and flags.get("wind", false))
	return false

func activate(action: String) -> bool:
	if not available(action):
		return false
	if action not in ["bell", "brake"]:
		flags[action] = true
	return true

func restore(value: int) -> void:
	checkpoint = clampi(value, 0, 2)
	flags.clear()
	var stages := {
		"laundry": [["drain"], ["cart_ready", "fill"]],
		"thread_vault": [["counterweight"], ["winch_a", "winch_b"]],
		"clocktower": [["brake_crossed"], ["wind", "release"]]
	}
	for stage in range(checkpoint):
		for action in stages[level_id][stage]:
			flags[action] = true

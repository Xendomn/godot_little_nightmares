extends RefCounted

static func configure() -> void:
	var bindings = {"left": KEY_A, "right": KEY_D, "depth_up": KEY_W, "depth_down": KEY_S, "jump": KEY_SPACE, "run": KEY_SHIFT, "crouch": KEY_CTRL, "interact": KEY_E, "pause": KEY_ESCAPE}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = bindings[action]
			InputMap.action_add_event(action, event)

extends RefCounted

static func configure() -> void:
	var bindings = {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "depth_up": [KEY_W, KEY_UP], "depth_down": [KEY_S, KEY_DOWN], "jump": [KEY_SPACE], "run": [KEY_SHIFT], "crouch": [KEY_CTRL], "interact": [KEY_E], "pause": [KEY_ESCAPE]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			add_event(action, event)
	var buttons = {"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "depth_up": JOY_BUTTON_DPAD_UP, "depth_down": JOY_BUTTON_DPAD_DOWN, "jump": JOY_BUTTON_A, "crouch": JOY_BUTTON_B, "interact": JOY_BUTTON_X, "pause": JOY_BUTTON_START, "ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B, "ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT, "ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN}
	for action in buttons:
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = buttons[action]
		add_event(action, event)
	for entry in [["left", JOY_AXIS_LEFT_X, -1.0], ["right", JOY_AXIS_LEFT_X, 1.0], ["depth_up", JOY_AXIS_LEFT_Y, -1.0], ["depth_down", JOY_AXIS_LEFT_Y, 1.0], ["run", JOY_AXIS_TRIGGER_RIGHT, 1.0], ["ui_left", JOY_AXIS_LEFT_X, -1.0], ["ui_right", JOY_AXIS_LEFT_X, 1.0], ["ui_up", JOY_AXIS_LEFT_Y, -1.0], ["ui_down", JOY_AXIS_LEFT_Y, 1.0]]:
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = entry[1]
		event.axis_value = entry[2]
		add_event(entry[0], event)
		InputMap.action_set_deadzone(entry[0], .5 if entry[0] == "run" or str(entry[0]).begins_with("ui_") else .22)

static func add_event(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

extends RefCounted
## Reuse the same route assertions with either action input or raw Xbox events.
static func press(action: String) -> void:
	set_action(action, true)
static func release(action: String) -> void:
	set_action(action, false)
static func set_action(action: String, down: bool) -> void:
	if not "--controller" in OS.get_cmdline_user_args():
		if down: Input.action_press(action)
		else: Input.action_release(action)
		return
	var buttons = {"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "depth_up": JOY_BUTTON_DPAD_UP, "depth_down": JOY_BUTTON_DPAD_DOWN, "jump": JOY_BUTTON_A, "crouch": JOY_BUTTON_B, "interact": JOY_BUTTON_X, "pause": JOY_BUTTON_START}
	if action == "run":
		var event := InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_TRIGGER_RIGHT
		event.axis_value = 1.0 if down else 0.0
		Input.parse_input_event(event)
	else:
		assert(buttons.has(action), "Unmapped test action: " + action)
		var event := InputEventJoypadButton.new()
		event.button_index = buttons[action]
		event.pressed = down
		Input.parse_input_event(event)
	Input.flush_buffered_events()

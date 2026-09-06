extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1
func run() -> void:
	preload("res://scripts/input_setup.gd").configure()
	for entry in [[KEY_LEFT, "left"], [KEY_RIGHT, "right"], [KEY_UP, "depth_up"], [KEY_DOWN, "depth_down"]]:
		var event := InputEventKey.new()
		event.physical_keycode = entry[0]
		event.pressed = true
		Input.parse_input_event(event.duplicate())
		Input.flush_buffered_events()
		check(Input.is_action_pressed(entry[1]), "arrow maps to " + entry[1])
		event.pressed = false
		Input.parse_input_event(event.duplicate())
		Input.flush_buffered_events()
	for entry in [[JOY_BUTTON_A, "jump"], [JOY_BUTTON_B, "crouch"], [JOY_BUTTON_X, "interact"], [JOY_BUTTON_START, "pause"], [JOY_BUTTON_DPAD_UP, "depth_up"]]:
		var event := InputEventJoypadButton.new()
		event.device = 2
		event.button_index = entry[0]
		event.pressed = true
		Input.parse_input_event(event.duplicate())
		Input.flush_buffered_events()
		check(Input.is_action_pressed(entry[1]), "Xbox button maps to " + entry[1])
		event.pressed = false
		Input.parse_input_event(event.duplicate())
		Input.flush_buffered_events()
	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = .1
	Input.parse_input_event(axis.duplicate())
	Input.flush_buffered_events()
	check(Input.get_vector("left", "right", "depth_up", "depth_down").is_zero_approx(), "stick drift ignored")
	axis.axis_value = .6
	Input.parse_input_event(axis.duplicate())
	Input.flush_buffered_events()
	var movement := Input.get_vector("left", "right", "depth_up", "depth_down")
	check(movement.x > .3 and movement.x < .8, "stick preserves analog movement")
	axis.axis_value = 0
	Input.parse_input_event(axis.duplicate())
	Input.flush_buffered_events()
	axis.axis = JOY_AXIS_TRIGGER_RIGHT
	axis.axis_value = .8
	Input.parse_input_event(axis.duplicate())
	Input.flush_buffered_events()
	check(Input.is_action_pressed("run"), "RT activates run")
	axis.axis_value = 0
	Input.parse_input_event(axis.duplicate())
	Input.flush_buffered_events()
	var count := InputMap.action_get_events("left").size()
	preload("res://scripts/input_setup.gd").configure()
	check(InputMap.action_get_events("left").size() == count, "reconfiguration is idempotent")
	print("CONNECTED JOYPADS: ", Input.get_connected_joypads())
	await process_frame
	quit(1 if failures else 0)

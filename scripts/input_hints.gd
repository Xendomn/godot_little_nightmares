extends Node
## Persistent device hints and release barrier for buttons used by menus.
signal device_changed
signal controller_lost
var using_controller := false
var controller_id := -1
var blocked: Dictionary = {}
const KEY_LABELS = {"move": "WASD / 方向键", "horizontal": "A/D 或 ←/→", "jump": "空格", "run": "Shift", "crouch": "Ctrl", "interact": "E", "pause": "Esc", "accept": "Enter", "cancel": "Esc"}
const PAD_LABELS = {"move": "左摇杆 / 十字键", "horizontal": "左摇杆 / 十字键左右", "jump": "A", "run": "RT", "crouch": "B", "interact": "X", "pause": "Menu", "accept": "A", "cancel": "B"}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	preload("res://scripts/input_setup.gd").configure()
	Input.joy_connection_changed.connect(connection_changed)

func _input(event: InputEvent) -> void:
	observe_event(event)

func observe_event(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		select_device(true, event.device)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > (.5 if event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] else .22):
		select_device(true, event.device)
	elif (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		select_device(false)

func select_device(controller: bool, id: int = -1) -> void:
	var changed := using_controller != controller
	using_controller = controller
	controller_id = id if controller else -1
	if changed:
		device_changed.emit()

func connection_changed(id: int, connected: bool) -> void:
	if not connected and using_controller and id == controller_id:
		select_device(false)
		controller_lost.emit()

func format_text(template: String) -> String:
	return template.format(PAD_LABELS if using_controller else KEY_LABELS)

func block_held() -> void:
	for action in ["jump", "interact", "crouch", "pause"]:
		if Input.is_action_pressed(action):
			blocked[action] = true

func _process(_delta: float) -> void:
	for action in blocked.keys():
		if not Input.is_action_pressed(action):
			blocked.erase(action)

func pressed(action: String) -> bool:
	return not blocked.has(action) and Input.is_action_pressed(action)

func just_pressed(action: String) -> bool:
	return not blocked.has(action) and Input.is_action_just_pressed(action)

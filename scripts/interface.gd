extends CanvasLayer

signal start_requested
signal resume_requested
signal restart_requested
signal quit_requested

var menu: Control
var pause_menu: Control
var ending: Control
var hud: Control
var objective: Label
var prompt: Label
var chapter: Label
var hint: Label
var threat: Label
var fade: ColorRect
var subtitles: Label
var notice_time: float = 0
var menu_button: Button
var elapsed_time: float = 0
const PAPER := Color("ded7c3")
const MUTED := Color("acb9b5")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var base := Control.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	var theme := Theme.new()
	if ResourceLoader.exists("res://assets/fonts/NotoSansSC.ttf"):
		var font := FontVariation.new()
		font.base_font = load("res://assets/fonts/NotoSansSC.ttf")
		font.variation_opentype = {2003265652: 450.0} # OpenType 'wght' axis.
		theme.default_font = font
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", PAPER)
	base.theme = theme
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = load("res://assets/shaders/vignette.gdshader")
	vignette.material = vignette_material
	base.add_child(vignette)
	# Quiet letterbox and grain/vignette keep the world cinematic.
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color("081016")
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.offset_bottom = 54 if top else 0
		bar.offset_top = 0 if top else -54
		base.add_child(bar)
	hud = full_control(base)
	chapter = label(hud, "01 / 工作台下", Vector2(66, 78), 18, MUTED)
	objective = label(hud, "寻找离开工坊的路", Vector2(66, 111), 25, PAPER)
	prompt = label(hud, "", Vector2(0, 860), 26, PAPER)
	prompt.size.x = 1920
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint = label(hud, "A D 移动    W S 纵深    空格 跳跃    Shift 奔跑    Ctrl 蹲伏", Vector2(66, 986), 18, MUTED)
	threat = label(hud, "", Vector2(1440, 80), 20, Color("edac81"))
	menu = full_control(base)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.03, 0.045, 0.68)
	shade.position = Vector2(0, 54)
	shade.size = Vector2(850, 972)
	menu.add_child(shade)
	label(menu, "一 则 机 械 童 话", Vector2(118, 200), 20, MUTED)
	label(menu, "午夜工坊", Vector2(110, 244), 88, PAPER)
	label(menu, "M I D N I G H T   W O R K S H O P", Vector2(118, 366), 20, Color("b18c61"))
	label(menu, "所有玩具都睡了。\n除了你，和那个守夜的人。", Vector2(118, 451), 25, MUTED)
	menu_button = button(menu, "开始旅程     →", Vector2(118, 606), func(): start_requested.emit())
	button(menu, "离开工坊", Vector2(118, 683), func(): quit_requested.emit())
	label(menu, "WASD 移动  /  空格 跳跃  /  E 互动", Vector2(118, 860), 18, MUTED)
	label(menu, "建议佩戴耳机  ·  原创短篇  ·  约 5–10 分钟", Vector2(118, 900), 17, MUTED)
	pause_menu = overlay(base)
	label(pause_menu, "让齿轮歇一会儿", Vector2(660, 265), 46, PAPER)
	button(pause_menu, "继续旅程", Vector2(740, 382), func(): resume_requested.emit())
	button(pause_menu, "从头开始", Vector2(740, 459), func(): restart_requested.emit())
	label(pause_menu, "声音", Vector2(740, 563), 20, MUTED)
	var volume := HSlider.new()
	volume.position = Vector2(820, 570)
	volume.size = Vector2(280, 30)
	volume.max_value = 1
	volume.step = 0.01
	volume.value = 0.8
	volume.value_changed.connect(func(value: float): AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, value))))
	pause_menu.add_child(volume)
	button(pause_menu, "退出游戏", Vector2(740, 653), func(): quit_requested.emit())
	pause_menu.hide()
	ending = overlay(base)
	label(ending, "天快亮了。", Vector2(720, 290), 62, PAPER)
	label(ending, "你不是一件坏掉的玩具。\n你只是想看看，工坊之外的世界。", Vector2(650, 410), 27, MUTED)
	button(ending, "再走一次     ↻", Vector2(740, 592), func(): restart_requested.emit())
	button(ending, "告别工坊", Vector2(740, 672), func(): quit_requested.emit())
	label(ending, "谢 谢 游 玩   ·   MIDNIGHT WORKSHOP", Vector2(680, 830), 17, MUTED)
	ending.hide()
	subtitles = label(base, "", Vector2(0, 765), 28, PAPER)
	subtitles.size.x = 1920
	subtitles.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.025, 0.04, 0.05, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_child(fade)
	hud.hide()
	menu_button.grab_focus()
	AudioServer.set_bus_volume_db(0, linear_to_db(0.8))

func full_control(parent: Control) -> Control:
	var result := Control.new()
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

func overlay(parent: Control) -> Control:
	var result := full_control(parent)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(0.02, 0.04, 0.05, 0.94)
	result.add_child(rect)
	return result

func label(parent: Control, text: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.position = pos
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	result.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(result)
	return result

func button(parent: Control, text: String, pos: Vector2, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.position = pos
	result.size = Vector2(440, 62)
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	result.add_theme_font_size_override("font_size", 25)
	result.add_theme_color_override("font_color", PAPER)
	result.add_theme_color_override("font_hover_color", Color("f0d7aa"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.09, 0.14, 0.16, 0.6)
	normal.border_color = Color("627976")
	normal.border_width_bottom = 1
	normal.content_margin_left = 23
	result.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.16, 0.23, 0.24, 0.9)
	hover.border_color = Color("caa77b")
	result.add_theme_stylebox_override("hover", hover)
	result.add_theme_stylebox_override("focus", hover)
	result.add_theme_stylebox_override("pressed", hover)
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func notice(text: String, seconds: float = 4) -> void:
	subtitles.text = text
	notice_time = seconds

func _process(delta: float) -> void:
	if notice_time > 0 and not get_tree().paused:
		notice_time -= delta
		if notice_time <= 0:
			subtitles.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and get_tree().paused:
		get_viewport().set_input_as_handled()
		resume_requested.emit()

func begin() -> void:
	menu.hide()
	ending.hide()
	pause_menu.hide()
	hud.show()

func set_pause(value: bool) -> void:
	pause_menu.visible = value
	if value:
		for node in pause_menu.get_children():
			if node is Button:
				node.grab_focus()
				break

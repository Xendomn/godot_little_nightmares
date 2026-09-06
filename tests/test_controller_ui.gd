extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for i in range(n): await process_frame
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1
func button(index: int, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(3)
func tap(index: int) -> void:
	await button(index, true)
	await button(index, false)
func axis(index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = index
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(3)
func capture(name: String, viewport: Viewport) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://artifacts/" + name + ".png")
func run() -> void:
	var campaign = load("res://scenes/main.tscn").instantiate()
	campaign.save_path = "user://controller-ui-test.json"
	var store = preload("res://scripts/campaign/save_store.gd").new(campaign.save_path)
	store.clear()
	root.add_child(campaign)
	await frames(8)
	var ui = campaign.chapter.ui
	await axis(JOY_AXIS_LEFT_Y, .8)
	check(root.gui_get_focus_owner().text == "关卡选择", "positive stick Y navigates down past disabled continue")
	await axis(JOY_AXIS_LEFT_Y, .85)
	check(root.gui_get_focus_owner().text == "关卡选择", "stick jitter does not repeat immediately")
	await axis(JOY_AXIS_LEFT_Y, 0)
	check(ui.hint.text.contains("RT"), "menu stick input immediately selects Xbox hints")
	await tap(JOY_BUTTON_A)
	check(ui.chapter_menu.visible, "controller opens chapter selection")
	await capture("controller-chapters", root)
	check(root.gui_get_focus_owner() != null and ui.chapter_menu.is_ancestor_of(root.gui_get_focus_owner()), "chapter selection owns focus")
	await tap(JOY_BUTTON_B)
	check(not ui.chapter_menu.visible, "B returns from chapter selection")
	await tap(JOY_BUTTON_DPAD_UP)
	await button(JOY_BUTTON_A, true)
	await frames(30)
	check(campaign.chapter.playing, "A starts campaign")
	check(campaign.chapter.player.position.y < .1, "menu A does not leak into jump")
	await button(JOY_BUTTON_A, false)
	await tap(JOY_BUTTON_START)
	check(paused and campaign.chapter.ui.pause_menu.visible, "Menu pauses campaign")
	await capture("controller-pause", root)
	ui = campaign.chapter.ui
	await tap(JOY_BUTTON_DPAD_DOWN)
	await tap(JOY_BUTTON_DPAD_DOWN)
	await tap(JOY_BUTTON_DPAD_DOWN)
	var volume = root.gui_get_focus_owner()
	check(volume is HSlider, "controller reaches volume slider")
	var previous_volume: float = volume.value
	await tap(JOY_BUTTON_DPAD_LEFT)
	check(volume.value < previous_volume, "controller adjusts volume")
	volume.value = previous_volume
	await tap(JOY_BUTTON_DPAD_DOWN)
	await tap(JOY_BUTTON_A)
	check(ui.confirm_new.visible, "controller opens new journey confirmation")
	check(ui.confirm_new.gui_get_focus_owner() == ui.confirm_new.get_cancel_button(), "destructive confirmation defaults to cancel")
	await capture("controller-confirm", ui.confirm_new)
	await tap(JOY_BUTTON_B)
	check(not ui.confirm_new.visible and paused, "B closes confirmation without resuming")
	await button(JOY_BUTTON_B, true)
	check(not paused, "B resumes pause")
	check(not campaign.chapter.player.crouching, "menu B does not leak into crouch")
	await button(JOY_BUTTON_B, false)
	await tap(JOY_BUTTON_X)
	check(campaign.chapter.ui.hint.text.contains("RT"), "controller updates HUD hints")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	Input.flush_buffered_events()
	await frames(3)
	escape = escape.duplicate()
	escape.echo = true
	Input.parse_input_event(escape)
	Input.flush_buffered_events()
	await frames(3)
	check(paused, "held Escape echo cannot dismiss pause")
	escape = escape.duplicate()
	escape.pressed = false
	escape.echo = false
	Input.parse_input_event(escape)
	Input.flush_buffered_events()
	await frames(3)
	await tap(JOY_BUTTON_B)
	await tap(JOY_BUTTON_X)
	get_root().get_node("InputHints").connection_changed(0, false)
	await frames(3)
	check(paused, "active controller disconnect pauses gameplay")
	get_root().get_node("InputHints").connection_changed(0, true)
	await frames(3)
	check(paused, "reconnecting never resumes automatically")
	await tap(JOY_BUTTON_B)
	await tap(JOY_BUTTON_START)
	for i in range(4): await tap(JOY_BUTTON_DPAD_DOWN)
	await tap(JOY_BUTTON_A)
	await tap(JOY_BUTTON_A)
	check(not ui.confirm_new.visible and paused, "A on default Cancel preserves journey")
	ui.request_new_journey()
	await frames(3)
	await tap(JOY_BUTTON_DPAD_LEFT)
	await tap(JOY_BUTTON_A)
	await frames(8)
	check(not paused and campaign.chapter.playing and not is_instance_valid(ui), "controller explicitly confirms new journey")
	await tap(JOY_BUTTON_X)
	campaign.chapter.respawning = true
	get_root().get_node("InputHints").connection_changed(0, false)
	campaign.chapter.respawning = false
	await frames(3)
	check(paused, "disconnect during respawn pauses when transition finishes")
	paused = false
	campaign.queue_free()
	await frames(4)
	store.clear()
	OS.delay_msec(120)
	quit(1 if failures else 0)

extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1920, 1080)
	var ui = load("res://scripts/interface.gd").new()
	root.add_child(ui)
	await process_frame
	check(ui.has_method("set_puzzle_hints"), "voluntary puzzle hints API exists")
	if not ui.has_method("set_puzzle_hints"):
		ui.queue_free()
		quit(1)
		return
	ui.enable_campaign(false, ["workshop"])
	ui.begin()
	ui.set_puzzle_hints("fuse", ["观察电缆。", "跟随电缆找到插座。", "将保险丝放入升降机插座。"])
	ui.set_pause(true)
	check(ui.hint_button.visible and not ui.hint_panel.visible and ui.hint_body.text.is_empty(), "pause offers hints without revealing an answer")
	ui.open_puzzle_hints()
	check(ui.hint_body.text.is_empty() and ui.current_panel() == ui.hint_panel, "opening hints requires voluntary reveal")
	ui.reveal_next_hint()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/puzzle-hint-first.png")
	check(ui.hint_body.text == "观察电缆。", "first reveal shows observation only")
	ui.reveal_next_hint()
	check(ui.hint_body.text.contains("跟随电缆") and not ui.hint_body.text.contains("放入"), "second reveal adds direction without solution")
	ui.reveal_next_hint()
	check(ui.hint_body.text.contains("放入") and ui.hint_next.disabled, "third reveal adds solution and disables further steps")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	ui._input(cancel)
	check(not ui.hint_panel.visible and ui.pause_menu.visible, "controller cancel returns to paused game menu")
	check(root.gui_get_focus_owner() == ui.hint_button, "controller focus returns to hint button")
	ui.set_puzzle_hints("fuse", ["观察电缆。", "跟随电缆找到插座。", "将保险丝放入升降机插座。"])
	check(ui.hint_step == 3, "same puzzle refresh retains requested hint depth")
	ui.set_puzzle_hints("drain", ["看看水位。", "找到排水口。", "打开排水阀。"])
	check(ui.hint_step == 0 and ui.hint_body.text.is_empty(), "new puzzle clears revealed answers")
	ui.set_puzzle_hints("", [])
	check(not ui.hint_button.visible, "legacy and unavailable hints hide optional action")
	ui.queue_free()
	await process_frame
	print("PUZZLE HINT FAILURES: ", failures)
	quit(1 if failures else 0)

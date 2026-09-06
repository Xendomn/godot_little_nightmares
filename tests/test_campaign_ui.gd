extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1
func frames(n: int) -> void:
	for i in range(n):
		await process_frame
func button(panel: Control, prefix: String) -> Button:
	for child in panel.get_children():
		if child is Button and child.visible and child.text.begins_with(prefix):
			return child
	return null
func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/" + name + ".png")
func run() -> void:
	var store = load("res://scripts/campaign/save_store.gd").new("res://artifacts/ui-test.json")
	store.clear()
	store.write_checkpoint("clocktower", 2, ["workshop", "laundry", "thread_vault", "clocktower"])
	var campaign = load("res://scenes/main.tscn").instantiate()
	campaign.save_path = store.path
	root.add_child(campaign)
	await frames(60)
	await capture("campaign-menu")
	button(campaign.chapter.ui.menu, "关卡选择").pressed.emit()
	await frames(4)
	await capture("chapter-select")
	button(campaign.chapter.ui.chapter_menu, "03").pressed.emit()
	await frames(5)
	check(campaign.level_index == 2, "chapter button captures its own index")
	campaign.chapter.toggle_pause()
	await frames(5)
	await capture("campaign-pause")
	button(campaign.chapter.ui.pause_menu, "重试检查点").pressed.emit()
	await frames(120)
	check(not paused and not campaign.chapter.respawning and campaign.chapter.player.enabled, "pause retry button restores input")
	campaign.chapter.toggle_pause()
	button(campaign.chapter.ui.pause_menu, "开始新旅程").pressed.emit()
	await frames(5)
	check(campaign.chapter.ui.confirm_new.visible and campaign.level_index == 2, "new journey waits for visible confirmation")
	campaign.chapter.ui.confirm_new.hide()
	check(campaign.level_index == 2, "cancel preserves chapter")
	campaign.chapter.ui.confirm_new.confirmed.emit()
	await frames(6)
	check(campaign.level_index == 0 and campaign.unlocked == ["workshop"] and not paused, "confirmed new journey replaces chapter")
	campaign.queue_free()
	await frames(5)
	store.clear()
	OS.delay_msec(120)
	print("CAMPAIGN UI FAILURES: ", failures)
	quit(1 if failures else 0)

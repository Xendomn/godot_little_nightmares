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
func run() -> void:
	var Store = load("res://scripts/campaign/save_store.gd")
	var isolated := "res://artifacts/campaign-integration.json"
	var store = Store.new(isolated)
	store.clear()
	var campaign = load("res://scenes/main.tscn").instantiate()
	campaign.save_path = isolated
	root.add_child(campaign)
	await frames(4)
	check(not campaign.chapter.playing and campaign.chapter.ui.menu.visible, "campaign starts at menu")
	campaign.start_new_journey()
	await frames(4)
	check(campaign.chapter.playing and campaign.saved.level_id == "workshop", "new journey starts and saves first chapter")
	campaign.select_chapter(3)
	check(campaign.level_index == 0, "locked chapter cannot be selected")
	for index in range(3):
		var old = weakref(campaign.chapter)
		campaign.chapter.level_completed.emit()
		await frames(90)
		check(campaign.level_index == index + 1 and campaign.saved.level_id == campaign.IDS[index + 1], "chapter completion unlocks and saves next " + str(index + 1))
		check(old.get_ref() == null and campaign.get_child_count() == 1, "old chapter unloaded " + str(index))
	campaign.chapter.restore_checkpoint(2)
	campaign.on_checkpoint(2)
	check(store.read_checkpoint().checkpoint_id == 2, "active checkpoint persisted")
	campaign.queue_free()
	await frames(5)
	campaign = load("res://scenes/main.tscn").instantiate()
	campaign.save_path = isolated
	root.add_child(campaign)
	await frames(4)
	campaign.continue_journey()
	await frames(4)
	check(campaign.level_index == 3 and campaign.chapter.rules.checkpoint == 2, "new process manager continues correct chapter and checkpoint")
	paused = true
	var platform = campaign.chapter.world.get_node("Lift")
	var before: Vector3 = platform.position
	await frames(20)
	check(platform.position.is_equal_approx(before), "pause freezes moving platform")
	paused = false
	campaign.replay_chapter()
	await frames(4)
	check(campaign.level_index == 3 and campaign.chapter.rules.checkpoint == 0, "replay resets only current chapter")
	campaign.start_new_journey()
	await frames(4)
	check(campaign.unlocked == ["workshop"] and campaign.level_index == 0, "new journey clears unlocks")
	campaign.queue_free()
	await frames(5)
	store.clear()
	OS.delay_msec(120)
	print("CAMPAIGN FAILURES: ", failures)
	quit(1 if failures else 0)

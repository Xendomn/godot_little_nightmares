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
	check(campaign.chapter.get("checkpoint_id") is String, "campaign loads expanded chapter with stable checkpoint IDs")
	if not campaign.chapter.get("checkpoint_id") is String:
		campaign.queue_free()
		await frames(2)
		store.clear()
		quit(1)
		return
	campaign.start_new_journey()
	await frames(4)
	check(campaign.chapter.playing and campaign.saved.get("level_id") == "workshop", "new journey starts and saves first chapter")
	campaign.select_chapter(3)
	check(campaign.level_index == 0, "locked chapter cannot be selected")
	for index in range(3):
		var old = weakref(campaign.chapter)
		campaign.chapter.level_completed.emit()
		await frames(90)
		check(campaign.level_index == index + 1 and campaign.saved.level_id == campaign.IDS[index + 1], "chapter completion unlocks and saves next " + str(index + 1))
		check(old.get_ref() == null and campaign.get_child_count() == 1, "old chapter unloaded " + str(index))
	var first_room = campaign.chapter.rooms[0]
	var gear = first_room.objects.gear
	var socket = first_room.objects.gear_socket
	first_room.objects.direction.state = 1
	gear.attach_to_socket(socket)
	socket.occupied = gear
	campaign.chapter.player.reset_to(Vector3(48, .08, 0))
	campaign.chapter.active_room = 1
	campaign.chapter.checkpoint("room_2")
	var stable: Dictionary = store.read_checkpoint()
	check(stable.version == 2 and stable.checkpoint_id == "room_2", "chapter checkpoint commits stable v2 snapshot")
	check(stable.flags.rooms["0"].objects.direction.state == 1 and stable.flags.rooms["0"].objects.gear.socket_id == socket.object_id, "checkpoint saves mechanism and attached object state")
	first_room.objects.direction.state = 2
	gear.detach_from_socket()
	socket.occupied = null
	gear.position += Vector3(4, 0, 0)
	campaign.chapter.toggle_pause()
	campaign.retry_checkpoint()
	await frames(60)
	check(not paused and not campaign.chapter.respawning and campaign.chapter.player.enabled, "checkpoint retry resumes controls after restoration")
	check(first_room.objects.direction.state == 1 and gear.socket == socket and socket.occupied == gear, "retry rolls machinery and moved gear back to saved snapshot")
	check(gear.global_position.is_equal_approx(socket.global_position), "retry restores moved object's saved socket position")
	check(store.read_checkpoint().flags == stable.flags, "retry does not replace persisted checkpoint with later mutations")
	campaign.queue_free()
	await frames(5)
	campaign = load("res://scenes/main.tscn").instantiate()
	campaign.save_path = isolated
	root.add_child(campaign)
	await frames(4)
	campaign.continue_journey()
	await frames(4)
	first_room = campaign.chapter.rooms[0]
	gear = first_room.objects.gear
	socket = first_room.objects.gear_socket
	check(campaign.level_index == 3 and campaign.chapter.checkpoint_id == "room_2", "fresh manager reloads stable checkpoint ID")
	check(first_room.objects.direction.state == 1 and gear.socket == socket and socket.occupied == gear, "fresh manager forwards complete object snapshot")
	check(gear.global_position.is_equal_approx(socket.global_position), "fresh manager restores saved object location")
	campaign.chapter.restore_checkpoint("room_6_mid")
	campaign.on_checkpoint("room_6_mid")
	check(store.read_checkpoint().checkpoint_id == "room_6_mid", "active checkpoint persisted")
	campaign.queue_free()
	await frames(5)
	campaign = load("res://scenes/main.tscn").instantiate()
	campaign.save_path = isolated
	root.add_child(campaign)
	await frames(4)
	campaign.continue_journey()
	await frames(4)
	check(campaign.level_index == 3 and campaign.chapter.checkpoint_id == "room_6_mid", "new process manager continues correct chapter and checkpoint")
	paused = true
	var before: Vector3 = campaign.chapter.player.position
	await frames(20)
	check(campaign.chapter.player.position.is_equal_approx(before), "pause freezes the active player")
	paused = false
	campaign.chapter.finish_game()
	check(campaign.chapter.ui.ending.visible and not campaign.chapter.playing, "final chapter completion presents ending and replay controls")
	campaign.replay_chapter()
	await frames(4)
	check(campaign.level_index == 3 and campaign.chapter.checkpoint_id == "room_1", "replay resets only current chapter")
	gear = campaign.chapter.rooms[0].objects.gear
	var interactions = campaign.chapter.player.get_node("Interactions")
	campaign.chapter.player.reset_to(Vector3(4, .08, 0))
	await frames(2)
	check(interactions.pickup(gear), "player can pick up checkpoint test gear through real interaction API")
	campaign.chapter.checkpoint("room_2")
	var carrying_save: Dictionary = store.read_checkpoint()
	check(carrying_save.flags.get("carrying") == [0.0, "gear"], "checkpoint records held object's room registry identity")
	var external_snapshot: Dictionary = campaign.chapter.get_checkpoint_snapshot()
	external_snapshot.rooms["0"].objects.gear.position[0] = -9999
	check(campaign.chapter.get_checkpoint_snapshot().rooms["0"].objects.gear.position[0] != -9999, "snapshot getter isolates nested mutable dictionaries and arrays")
	interactions.cancel_interaction()
	gear.position.x += 4
	campaign.retry_checkpoint()
	await frames(60)
	check(interactions.carried == gear and gear.held, "retry restores item to player's hands")
	check(gear.global_position.distance_to(campaign.chapter.player.global_position) < 1, "restored held item follows player instead of dropping at stale position")
	campaign.queue_free()
	await frames(5)
	campaign = load("res://scenes/main.tscn").instantiate()
	campaign.save_path = isolated
	root.add_child(campaign)
	await frames(4)
	campaign.continue_journey()
	await frames(4)
	gear = campaign.chapter.rooms[0].objects.gear
	check(campaign.chapter.player.get_node("Interactions").carried == gear and gear.held, "fresh manager reload preserves carried object identity")
	campaign.start_new_journey()
	await frames(4)
	check(campaign.unlocked == ["workshop"] and campaign.level_index == 0, "new journey clears unlocks")
	campaign.queue_free()
	await frames(5)
	store.clear()
	# Migration uses only this isolated test path and preserves the original bytes.
	var archive := isolated + ".v1.bak"
	if FileAccess.file_exists(archive):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(archive))
	store.write_checkpoint("laundry", 2, ["workshop", "laundry"], {"old_water": true})
	var original := FileAccess.get_file_as_bytes(isolated)
	campaign = load("res://scenes/main.tscn").instantiate()
	campaign.save_path = isolated
	root.add_child(campaign)
	await frames(4)
	check(campaign.saved.version == 2 and campaign.saved.checkpoint_id == "room_1", "campaign explicitly migrates old saves")
	check(campaign.chapter.ui.subtitles.text.contains("备份"), "migration notice explains original backup")
	campaign.continue_journey()
	await frames(4)
	check(campaign.level_index == 1 and campaign.chapter.checkpoint_id == "room_1" and campaign.unlocked == ["workshop", "laundry"], "migration retains chapter and unlocks while restarting expanded chapter")
	check(FileAccess.get_file_as_bytes(archive) == original, "campaign migration archives original bytes unchanged")
	campaign.queue_free()
	await frames(5)
	store.clear()
	store.write_checkpoint("clocktower", 1, ["workshop", "laundry", "thread_vault", "clocktower"])
	var protected_bytes := FileAccess.get_file_as_bytes(isolated)
	campaign = load("res://scenes/main.tscn").instantiate()
	campaign.save_path = isolated
	root.add_child(campaign)
	await frames(4)
	check(campaign.store.migration_failed and campaign.chapter.ui.has_campaign_save, "failed migration retains new-journey confirmation")
	campaign.select_chapter(0)
	await frames(4)
	check(FileAccess.get_file_as_bytes(isolated) == protected_bytes, "playing after failed migration cannot overwrite preserved progress")
	campaign.queue_free()
	await frames(5)
	store.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(archive))
	OS.delay_msec(120)
	print("CAMPAIGN FAILURES: ", failures)
	quit(1 if failures else 0)

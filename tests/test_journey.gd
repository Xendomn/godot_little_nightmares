extends "res://tests/test_full_routes.gd"
## Real menu input and continuous campaign transitions, using the physical routes.
## Only test setup injects a save path; progress never calls campaign/game actions.
var campaign: Node
var isolated_save: String

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capture" in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/guidance-journey-" + label + ".png")

func key_tap(key: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frame(3)

func attach_campaign() -> void:
	campaign = load("res://scenes/main.tscn").instantiate()
	campaign.save_path = isolated_save
	root.add_child(campaign)
	await frame(15)

func sync_chapter() -> void:
	chapter = campaign.chapter
	actor = chapter.player

func verify_retry_and_continue() -> bool:
	if not await walk_to(Vector3(48, actor.global_position.y, 0)):
		return false
	if chapter.checkpoint_id != "room_2" or campaign.saved.checkpoint_id != "room_2":
		return fail("Walking into room 2 did not persist its checkpoint")
	var stable: Dictionary = campaign.store.read_checkpoint()
	var spawn: Array = stable.flags.spawn
	var saved_position := Vector3(float(spawn[0]), float(spawn[1]), float(spawn[2]))
	var route := find_object("route")
	var saved_state: int = route.state
	if not await use_object("route"):
		return false
	if route.state == saved_state:
		return fail("Room 2 interaction did not change the machine before retry")
	await key_tap(KEY_ESCAPE)
	if not paused or not chapter.ui.pause_menu.visible:
		return fail("Escape did not open pause menu")
	var position_before: Vector3 = actor.global_position
	await frame(12)
	if not actor.global_position.is_equal_approx(position_before):
		return fail("Pause did not freeze the player")
	await key_tap(KEY_DOWN)
	await key_tap(KEY_ENTER)
	await frame(90)
	if paused or chapter.respawning or not actor.enabled or chapter.ui.pause_menu.visible:
		return fail("Pause-menu checkpoint retry did not restore playable controls")
	if route.state != saved_state or actor.global_position.distance_to(saved_position) > .3:
		return fail("Retry did not restore the saved machine and player position")
	if campaign.store.read_checkpoint().flags != stable.flags:
		return fail("Retry overwrote the checkpoint with later machine state")
	print("PASS: keyboard pause and checkpoint retry restore physical room 2 progress")
	campaign.queue_free()
	chapter = null
	actor = null
	await frame(8)
	await attach_campaign()
	if not campaign.chapter.ui.menu.visible or not campaign.chapter.ui.has_campaign_save:
		return fail("Fresh manager did not offer saved journey in the main menu")
	await key_tap(KEY_DOWN)
	await key_tap(KEY_ENTER)
	await frame(15)
	sync_chapter()
	if not chapter.playing or chapter.level_id != "workshop" or chapter.checkpoint_id != "room_2" or chapter.active_room != 1:
		return fail("Keyboard Continue did not restore room 2")
	if not chapter.rooms[0].completed or find_object("route").state != saved_state:
		return fail("Continue did not preserve completed room and machine snapshot")
	print("PASS: fresh manager continues the saved journey through keyboard menu input")
	return true

func perform_route_action(action: String) -> bool:
	return await execute_action(action)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	isolated_save = "res://artifacts/journey-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	await attach_campaign()
	await capture("menu")
	if not campaign.chapter.ui.menu.visible or campaign.chapter.playing:
		fail("Fresh campaign must start in the main menu")
	else:
		await key_tap(KEY_ENTER)
		await frame(15)
		sync_chapter()
		if not chapter.playing or chapter.ui.menu.visible:
			fail("Enter did not start a new journey")
	for id in CONTENT.IDS:
		if not failures.is_empty(): break
		chapter_id = id
		sync_chapter()
		if chapter.level_id != id:
			fail("Campaign did not transition to " + id)
			break
		for index in 6:
			room_index = index
			if id == "workshop" and index == 1:
				if not await verify_retry_and_continue(): break
			print("JOURNEY %s room %d" % [id, index + 1])
			for action in ROUTES[id][index]:
				if not await perform_route_action(action): break
			if not failures.is_empty(): break
			await frame(10)
			if not current_room().completed:
				fail("Physical route did not complete the room")
				break
			completed += 1
			print("PASS: continuous journey %s room %d" % [id, index + 1])
			await capture("%s-%d" % [id, index + 1])
			if not await walk_to(Vector3(index * 46 + 45, actor.global_position.y, 0)): break
		if not failures.is_empty(): break
		if id != "clocktower":
			var previous: WeakRef = weakref(chapter)
			for _wait in 180:
				if campaign.chapter != previous.get_ref(): break
				await frame()
			await frame(10)
			chapter = null
			actor = null
			if previous.get_ref() != null or campaign.get_child_count() != 1:
				fail("Chapter transition did not unload the previous chapter")
				break
	await frame(10)
	if failures.is_empty():
		sync_chapter()
		if completed != 24 or not chapter.ui.ending.visible or chapter.playing or actor.enabled:
			fail("All 24 rooms must reach the final ending with gameplay stopped")
		elif campaign.unlocked.size() != 4 or campaign.saved.level_id != "clocktower":
			fail("Ending did not preserve campaign unlocks and final chapter save")
		else:
			print("PASS: final ending after all 24 rooms and four campaign chapters")
			await capture("ending")
	release_inputs()
	paused = false
	campaign.store.clear()
	campaign.queue_free()
	chapter = null
	actor = null
	await frame(8)
	OS.delay_msec(150)
	print("JOURNEY ROOMS PASSED: %d / 24; FAILURES: %d" % [completed, failures.size()])
	quit(1 if not failures.is_empty() else 0)

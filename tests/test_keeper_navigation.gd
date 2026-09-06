extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func run() -> void:
	for entry in [["workshop", 36.5], ["workshop", 43.0], ["laundry", 37.0], ["laundry", 44.0], ["thread_vault", 46.0], ["thread_vault", 52.5]]:
		var id: String = entry[0]
		var game = load("res://scenes/chapters/" + id + ".tscn").instantiate()
		root.add_child(game)
		await frames(4)
		game.start_game()
		game.set_process(false)
		game.player.set_physics_process(false)
		var y := 2.6 if id == "laundry" else 0.0
		var table: float = entry[1]
		print("TABLE SCENARIO ", id, " x=", table)
		var keeper = game.keeper
		check(game.has_node("KeeperNavigation"), id + " has authored ground navigation")
		for direction in [-1, 1]:
			keeper.reset_keeper()
			keeper.position = Vector3(table - direction * 3.2, y + .05, 1.15)
			game.player.position = Vector3(table + direction * 3.2, y + .05, 1.15)
			var escaped := false
			var max_height := y
			for i in range(700):
				keeper.active = true
				keeper.mode = keeper.Mode.CHASE
				keeper.suspicion = 1
				keeper.lost_time = 0
				keeper.last_seen = game.player.position
				keeper.grace = 10
				await frames(1)
				max_height = maxf(max_height, keeper.position.y)
				if direction * (keeper.position.x - table) > 2.5:
					escaped = true
					break
			check(escaped, id + " pursuer routes around table direction " + str(direction))
			check(max_height < y + .15, id + " keeper stays on ground")
		# Hidden targets must not cause sustained walking into the underside.
		game.player.crouching = true
		game.player.position = Vector3(table, y + .03, 1.15)
		keeper.position = Vector3(table + 2.6, y + .03, 1.15)
		keeper.mode = keeper.Mode.CHASE
		keeper.last_seen = game.player.position
		keeper.lost_time = 0
		keeper.active = true
		await frames(660)
		check(keeper.mode != keeper.Mode.CHASE and keeper.position.z < -.5, id + " hidden target returns to clear patrol aisle")
		game.queue_free()
		await frames(4)
	OS.delay_msec(120)
	print("NAVIGATION FAILURES: ", failures)
	quit(1 if failures else 0)

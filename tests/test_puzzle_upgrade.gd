extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var content = load("res://scripts/puzzles/campaign_content.gd")
	var laundry: Array = content.rooms("laundry")
	check(not laundry[1].has("lift"), "wooden raft puzzle must use buoyancy instead of cargo lift")
	check(laundry[2].get("machine", "") == "twin_water", "linked tank room authors a volume transfer mechanism")
	var vault: Array = content.rooms("thread_vault")
	check(vault[1].get("machine", "") == "weight_exchange", "second weight puzzle has distinct exchange rule")
	check(vault[5].devices.any(func(d): return d.id == "pin_c"), "third bridge has independent physical locking pin")
	var clock: Array = content.rooms("clocktower")
	check(clock[3].get("machine", "") == "shaft_sync", "fast and slow axes require actual synchronization")
	check(clock[4].devices.any(func(d): return "clock_aligned" in d.get("needs", [])), "clock release depends on physical angle")
	if failures:
		quit(1)
		return
	for id in content.IDS:
		var chapter = load("res://scenes/chapters/full/"+id+".tscn").instantiate()
		chapter.managed = true
		root.add_child(chapter)
		chapter.start_game()
		chapter.set_process(false)
		chapter.player.set_physics_process(false)
		for room in chapter.rooms:
			room.set_physics_process(false)
			check(not room.all_met(room.spec.goal), "unsolved physical goal " + id + "/" + str(room.index+1))
			var snapshot: Dictionary = room.capture_state()
			room.restore_state(JSON.parse_string(JSON.stringify(snapshot)))
			check(room.capture_state() == snapshot, "new mechanism snapshot roundtrip " + id + "/" + str(room.index+1))
			check(room.stage_objective() == room.spec.objective, "HUD describes problem without revealing solution")
		if id == "workshop":
			var r = chapter.rooms[2]
			r.objects.crate.position.x = 26
			r.machines.tick(.1)
			check(r.met("cargo_caught"), "cargo stop catches delivered crate")
			r.objects.crate.position.x = 14
			check(not r.met("cargo_caught"), "cargo latch cannot claim delivery after crate removed")
		if id == "clocktower":
			var r = chapter.rooms[4]
			r.objects.phase.state = 3
			check(not r.met("clock_aligned"), "dial selection cannot fake physical alignment")
		if id == "laundry":
			var r = chapter.rooms[2]
			check(r.has_method("safe_checkpoint_surface"), "water room recognizes permanent mid-checkpoint ledges")
			if r.has_method("safe_checkpoint_surface"):
				await physics_frame
				check(r.safe_checkpoint_surface(Vector3(26,3.2,0)), "central dry island supports mid-room checkpoint")
				check(not r.safe_checkpoint_surface(Vector3(33,2.55,0)), "floating deck cannot become a stable checkpoint")
				check(not r.safe_checkpoint_surface(Vector3(33,.03,0)), "submerged floor cannot become a checkpoint")
		chapter.free()
		await process_frame
	quit(1 if failures else 0)

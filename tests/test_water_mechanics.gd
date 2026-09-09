extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value: failures += 1
func advance(room: Node3D, seconds: float) -> void:
	for i in int(seconds * 60):
		room.machines.tick(1.0 / 60)
		await physics_frame
func jump_right(actor: CharacterBody3D, count: int = 43) -> void:
	actor.velocity = Vector3(4.6,7.2,0)
	for i in count:
		actor.velocity.x = 4.6
		actor.velocity.y -= 20.0 / 60
		actor.move_and_slide()
		await physics_frame
func run() -> void:
	var game = load("res://scenes/chapters/full/laundry.tscn").instantiate()
	game.managed = true
	root.add_child(game)
	await physics_frame
	for room in game.rooms: room.set_physics_process(false)
	game.player.set_physics_process(false)
	game.set_process(false)
	var actor = game.player
	var drain = game.rooms[0]
	check(drain.machines.water_machine != null, "water rooms install physical water mechanisms")
	if drain.machines.water_machine == null:
		game.free()
		quit(1)
		return
	drain.objects.drain.state = 1
	await advance(drain,1)
	check(not drain.met("water_low"), "open drain cannot defeat running inlet")
	drain.objects.inlet.state = 0
	await advance(drain,1)
	check(not drain.met("water_low"), "draining requires actual water travel")
	await advance(drain,4)
	check(drain.met("water_low") and drain.water.water_level < .16, "draining lowers rendered water and enables safe crossing")
	drain.objects.inlet.state = 1
	await advance(drain,3)
	check(not drain.met("water_low"), "inlet refills drained basin")
	var raft = game.rooms[1]
	var crate = raft.objects.crate
	check(raft.lift == null, "raft ascent has no cargo lift")
	raft.objects.fill.state = 1
	await advance(raft,5)
	check(not raft.met("raft_high") and crate.position.y < .2, "water cannot raise a crate outside its basin")
	raft.objects.fill.state = 2
	await advance(raft,5)
	crate.position.x = 21.3
	raft.objects.fill.state = 1
	await advance(raft,5)
	check(not raft.met("raft_high") and crate.position.y < 1.2, "physical closed hatch restricts raft rise")
	raft.objects.roof_hatch.state = 1
	await advance(raft,2)
	check(raft.met("raft_high") and crate.position.y > 1.5, "aligned crate actually floats to high exit")
	var saved: Dictionary = raft.capture_state()
	crate.position.x = 17.5
	raft.restore_state(saved)
	raft.restore_state(saved)
	check(absf(crate.position.x - 21.3) < .02 and raft.met("raft_high"), "repeated restore preserves moved floating crate and water")
	raft.objects.fill.state = 2
	await advance(raft,5)
	check(crate.position.y < .1 and not raft.met("raft_high"), "draining returns crate to reachable floor")
	actor.global_position = crate.global_position + Vector3(0,1.03,0)
	actor.velocity = Vector3.ZERO
	raft.objects.fill.state = 1
	for i in 310:
		raft.machines.tick(1.0 / 60)
		actor.velocity.y -= 20.0 / 60
		actor.move_and_slide()
		await physics_frame
	check(actor.position.y > 2.6 and absf(actor.position.y - crate.position.y - 1) < .06, "player rides actual moving crate collision to high water")
	await jump_right(actor)
	check(raft.to_local(actor.global_position).x > 23.1 and actor.position.y >= 3.17 and actor.is_on_floor(), "normal jump trajectory from raised crate lands on upper walkway")
	var twin = game.rooms[2]
	var water = twin.machines.water_machine
	check(water.basins.size() == 2 and water.floats.size() == 2, "transfer room has two distinct basins and rideable floats")
	twin.objects.transfer.state = 1
	await advance(twin,1)
	check(not twin.met("left_high"), "transfer setting cannot immediately unlock high valve")
	await advance(twin,4)
	check(twin.met("left_high") and not twin.met("right_high"), "transferred volume raises left float")
	check(absf(water.circuit.left + water.circuit.right - 1.9) < .001, "transfer conserves the shared water volume")
	actor.global_position = twin.to_global(Vector3(17,1.34,0))
	await jump_right(actor)
	check(twin.to_local(actor.global_position).x > 18.1 and actor.position.y > 2.5 and actor.is_on_floor(), "boarding bank permits a normal jump onto the high left float")
	actor.global_position = twin.to_global(Vector3(21.4,2.54,0))
	await jump_right(actor)
	check(twin.to_local(actor.global_position).x > 23.2 and actor.position.y > 3.17 and actor.is_on_floor(), "left float permits a normal jump onto the dry central ledge")
	game.playing = true
	twin._physics_process(1.0 / 60)
	check(not twin.ladder.is_in_group("puzzle_interactable"), "reaching central ledge cannot unlock return ladder and bypass right float")
	game.playing = false
	twin.objects.upper_transfer.state = 1
	await advance(twin,1)
	check(twin.met("left_high"), "upper transfer cannot operate before left valve")
	twin.objects.left_valve.state = 1
	await advance(twin,5)
	check(twin.met("right_high") and not twin.met("left_high"), "upper valve reverses volume into right tank")
	check(absf(water.circuit.left + water.circuit.right - 1.9) < .001, "upper transfer also conserves total volume")
	actor.global_position = twin.to_global(Vector3(28.6,3.19,0))
	await jump_right(actor,49)
	check(twin.to_local(actor.global_position).x > 31.1 and actor.position.y > 2.5 and actor.is_on_floor(), "central gap can be crossed onto raised right float")
	actor.global_position = twin.to_global(Vector3(34,2.54,0))
	await jump_right(actor)
	check(twin.to_local(actor.global_position).x > 35.6 and actor.position.y > 3.17 and actor.is_on_floor(), "right float gives physical access to outlet landing")
	game.playing = true
	twin.objects.right_valve.state = 1
	twin._physics_process(1.0 / 60)
	check(twin.ladder.is_in_group("puzzle_interactable"), "right outlet releases the return ladder for safe descent")
	game.playing = false
	var pressure = game.rooms[4]
	pressure.objects.wheel.attach_to_socket(pressure.objects.bypass)
	pressure.objects.bypass.occupied = pressure.objects.wheel
	pressure.objects.pressure.state = 1
	await advance(pressure,5)
	check(pressure.met("water_high") and not pressure.met("hydraulic_ready"), "high water alone cannot drive an airlocked piston")
	pressure.objects.pressure.state = 2
	await advance(pressure,2)
	check(not pressure.met("hydraulic_ready"), "supply mode without vent remains airlocked")
	pressure.objects.vent.state = 1
	await advance(pressure,2)
	check(pressure.met("hydraulic_ready"), "vented water head extends hydraulic piston")
	pressure.objects.pressure.state = 0
	await advance(pressure,2)
	check(not pressure.met("hydraulic_ready"), "off safely releases driving pressure")
	game.playing = true
	var flood = drain.machines.water_machine
	flood.circuit.left = 1.9
	actor.global_position = drain.to_global(Vector3(14,.03,0))
	flood.check_submersion(2)
	check(not game.respawning and not flood.warning.visible, "deep water never kills player outside the basin")
	actor.global_position = drain.to_global(Vector3(24,.03,0))
	flood.check_submersion(.8)
	check(not game.respawning and flood.warning.visible, "submersion gives a visible warning before death")
	actor.global_position.y = 2.0
	flood.check_submersion(.8)
	check(not game.respawning and not flood.warning.visible, "escaping above the water clears drowning warning")
	actor.global_position.y = .03
	flood.check_submersion(.9)
	check(not game.respawning, "fresh submersion starts a new warning period")
	flood.check_submersion(.4)
	check(game.respawning, "remaining physically submerged triggers checkpoint failure")
	game.free()
	OS.delay_msec(250)
	await physics_frame
	print("WATER MECHANICS FAILURES: ", failures)
	quit(1 if failures else 0)

extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1
func run() -> void:
	var path := "res://scripts/props/prop_visual.gd"
	check(ResourceLoader.exists(path), "mechanical visual controller exists")
	if not ResourceLoader.exists(path):
		quit(1)
		return
	var prop = load(path).new()
	prop.kind = "drain"
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	prop.add_child(rotor)
	root.add_child(prop)
	await process_frame
	prop.set_active(true, true)
	check(absf(rotor.rotation.z) > 1, "activated valve visibly rotates")
	prop.play_feedback()
	prop.play_feedback()
	prop.set_active(false, true)
	check(rotor.rotation.is_zero_approx(), "checkpoint reset restores original pose immediately")
	prop.kind = "bell"
	var bell := Node3D.new()
	bell.name = "Bell"
	prop.add_child(bell)
	prop.cache_pivots()
	prop.play_feedback()
	for i in range(10): await process_frame
	check(absf(bell.rotation.z) > .01, "bell feedback swings actual bell")
	paused = true
	var pose: float = bell.rotation.z
	for i in range(10): await process_frame
	check(is_equal_approx(pose, bell.rotation.z), "pause freezes prop feedback")
	paused = false
	prop.set_active(false, true)
	check(bell.rotation.is_zero_approx(), "reset cancels ongoing bell swing")
	prop.queue_free()
	var water = load("res://scripts/props/draining_water.gd").new()
	water.position.y = .15
	root.add_child(water)
	water.set_drained(true, true)
	check(not water.visible and water.position.y < 0, "restored drain immediately lowers water surface")
	water.set_drained(false, true)
	check(water.visible and is_equal_approx(water.position.y, .15), "new journey restores original water level")
	water.queue_free()
	await process_frame
	await process_frame
	OS.delay_msec(120)
	quit(1 if failures else 0)

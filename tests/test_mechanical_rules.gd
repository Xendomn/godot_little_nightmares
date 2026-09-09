extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func _initialize() -> void:
	var paths := ["water_circuit", "counterweight_motion", "shaft_clock", "hazard_cycle"]
	for component in paths:
		check(ResourceLoader.exists("res://scripts/puzzles/" + component + ".gd"), component + " simulation exists")
	if failures:
		quit(1)
		return
	var water = load("res://scripts/puzzles/water_circuit.gd").new()
	water.left = 1.9
	water.right = 0.0
	for i in 1000: water.transfer(.017, false)
	check(is_equal_approx(water.left + water.right, 1.9), "dual tanks conserve water through transfer")
	check(is_zero_approx(water.left) and is_equal_approx(water.right, 1.9), "transfer stops at empty source")
	water.transfer(1.0, true)
	check(water.left > 0 and water.right < 1.9, "water transfer is reversible")
	var saved: Dictionary = water.capture_state()
	water.fill(100)
	water.restore_state(saved)
	check(water.capture_state() == saved, "water snapshot preserves intermediate volume")
	water.drain(100)
	check(is_zero_approx(water.left), "draining clamps at basin floor")
	var weights = load("res://scripts/puzzles/counterweight_motion.gd").new()
	check(weights.target_height(0) < weights.target_height(1) and weights.target_height(1) < weights.target_height(2), "one and two weights produce different landings")
	weights.advance(10, 2)
	weights.lock()
	weights.advance(10, 0)
	check(is_equal_approx(weights.height, 3.11), "physical pin retains raised platform after weight removal")
	var shafts = load("res://scripts/puzzles/shaft_clock.gd").new()
	shafts.advance(3, true, false)
	check(not shafts.aligned(), "two powered shaft speeds do not imply alignment")
	var before: float = shafts.fast
	shafts.advance(1, true, true)
	check(is_equal_approx(before, shafts.fast) and shafts.slow > 0, "brake freezes fast shaft while slow shaft advances")
	shafts.fast = PI
	shafts.slow = PI
	check(shafts.aligned(), "matching marks permit coupling")
	check(not shafts.at_mark(3), "selected mark alone does not align clock")
	shafts.slow = PI * 1.5
	check(shafts.at_mark(3), "actual clock angle enters marked window")
	var cycle = load("res://scripts/puzzles/hazard_cycle.gd").new()
	cycle.advance(2.3, false)
	var pose: float = cycle.angle()
	cycle.advance(4, true)
	check(is_equal_approx(cycle.angle(), pose), "brake freezes actual pendulum pose")
	var state: Dictionary = cycle.capture_state()
	cycle.advance(2, false)
	cycle.restore_state(state)
	check(is_equal_approx(cycle.angle(), pose), "hazard restore preserves visual phase")
	cycle.time = 0
	check(cycle.steam_stage() == "warning", "steam starts with one second warning")
	cycle.time = 1.2
	check(cycle.steam_stage() == "active", "steam damage follows visible active stage")
	cycle.time = 5
	check(cycle.steam_stage() == "safe", "steam safe interval supports waiting and crossing")
	var warning_seconds := 0.0
	for i in 1000:
		cycle.time = float(i) / 100.0
		if cycle.pendulum_stage() == "warning": warning_seconds += .01
		if cycle.pendulum_stage() == "active": break
	check(warning_seconds >= 1.0, "pendulum gives at least one second warning before its low pass")
	quit(1 if failures else 0)

extends SceneTree

var failures := 0
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1

func _initialize() -> void:
	var Rules = load("res://scripts/chapters/chapter_rules.gd")
	var laundry = Rules.new("laundry")
	check(not laundry.activate("fill"), "cannot fill before cart and drain")
	check(laundry.activate("drain"), "drain opens laundry route")
	check(not laundry.activate("fill"), "draining alone does not activate loaded lift")
	check(laundry.activate("cart_ready") and laundry.activate("fill"), "cart on plate enables lift")
	check(not laundry.activate("fill"), "duplicate fill does not restart lift")
	laundry.restore(1)
	check(laundry.flags.get("drain", false) and not laundry.flags.get("fill", false), "laundry checkpoint restores drain but resets cart puzzle")
	var vault = Rules.new("thread_vault")
	check(not vault.activate("winch_b"), "winches enforce bridge order")
	check(vault.activate("counterweight") and vault.activate("winch_a") and vault.activate("winch_b"), "counterweight and winches build full bridge")
	check(vault.activate("bell") and vault.activate("bell"), "bell decoy remains reusable")
	vault.restore(2)
	check(vault.flags.get("winch_b", false), "vault checkpoint keeps escape bridge assembled")
	var clock = Rules.new("clocktower")
	check(clock.activate("brake") and clock.activate("brake"), "pendulum brake can be retried")
	check(not clock.activate("release"), "bell hammer cannot skip upper lift")
	check(clock.activate("brake_crossed") and clock.activate("wind") and clock.activate("release"), "clocktower sequence reaches final chase")
	clock.restore(0)
	check(clock.flags.is_empty(), "restart clears chapter flags")
	print("CHAPTER RULE FAILURES: ", failures)
	quit(1 if failures else 0)

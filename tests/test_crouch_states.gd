extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
func run() -> void:
	var game = load("res://scenes/chapters/workshop.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var driver = game.player.visual_driver
	driver.update_motion(.3, true, true, false, 0)
	check(driver.current == "crouch_walk", "crouch movement begins above upper threshold")
	driver.update_motion(.15, true, true, false, 0)
	check(driver.current == "crouch_walk", "crouch movement holds across speed dead band")
	driver.update_motion(.05, true, true, false, 0)
	check(driver.current == "crouch", "crouch movement stops below lower threshold")
	driver.update_motion(.15, true, true, false, 0)
	check(driver.current == "crouch", "stationary crouch does not jitter into walking")
	game.queue_free()
	await process_frame
	await process_frame
	OS.delay_msec(120)
	quit(1 if failures else 0)

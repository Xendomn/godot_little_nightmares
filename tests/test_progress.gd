extends SceneTree

var failures: int = 0

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error("FAIL: " + description)
		failures += 1
	else:
		print("PASS: " + description)

func _initialize() -> void:
	var state = load("res://scripts/progress.gd").new()
	check(not state.activate_power(), "cannot bypass missing fuse")
	check(not state.install_fuse(), "cannot install an uncollected fuse")
	check(state.collect_fuse(), "collect fuse once")
	check(not state.collect_fuse(), "duplicate pickup has no side effect")
	state.enter_checkpoint(1)
	check(state.install_fuse(), "carried fuse powers panel")
	check(not state.has_fuse, "install consumes held fuse")
	check(not state.install_fuse(), "duplicate install rejected")
	state.restore_checkpoint()
	check(state.has_fuse and not state.fuse_installed and not state.power_on, "workshop death restores a usable fuse")
	state.install_fuse()
	check(state.activate_power(), "switch after fuse starts conveyor")
	check(not state.activate_power(), "duplicate switch rejected")
	state.enter_checkpoint(2)
	state.restore_checkpoint()
	check(state.power_on and state.fuse_installed and not state.has_fuse, "chase death preserves powered route")
	state.enter_checkpoint(0)
	check(state.checkpoint == 2, "walking backward cannot erase checkpoint")
	print("Progress failures: ", failures)
	quit(1 if failures else 0)

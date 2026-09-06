extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count): await process_frame
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func inspect(node: Node) -> bool:
	if node is Label3D:
		var words: String = node.text.strip_edges()
		if words in ["DRAIN", "FILL", "BELL", "WINCH A", "WINCH B", "BRAKE", "WIND", "RELEASE", "LOAD", "FUSE", "POWER", "CROUCH"] or words.begins_with("OUTSIDE"):
			return false
	for child in node.get_children():
		if not inspect(child): return false
	return true
func run() -> void:
	for id in ["drain", "fill", "winch_a", "winch_b", "bell", "brake", "wind", "release", "fuse_box", "power_switch", "laundry_cart", "spool_carrier", "pressure_plate", "steam_pipe", "last_bell", "exit_workshop", "exit_laundry", "exit_vault", "exit_clocktower"]:
		check(ResourceLoader.exists("res://scenes/props/" + id + ".tscn"), "editable modeled prop " + id)
	if failures:
		quit(1)
		return
	for id in ["workshop", "laundry", "thread_vault", "clocktower"]:
		var game = load("res://scenes/chapters/" + id + ".tscn").instantiate()
		root.add_child(game)
		await frames(4)
		game.start_game()
		check(inspect(game), id + " has no functional text placeholders")
		var world: Node3D = game.get_node("World")
		check(world.has_node("ExitVisual/Model"), id + " has modeled exit")
		if id == "workshop":
			game.state.collect_fuse()
			game.state.install_fuse()
			game.refresh_world()
			check(world.get_node("PanelVisual").active, "installed fuse appears in actual fuse box")
			game.restore_checkpoint(0)
			check(not world.get_node("PanelVisual").active, "workshop reset removes installed visual fuse")
		else:
			for item in world.get_children():
				if item.has_method("sync_visual"):
					check(item.has_node("Visual/Model") and not item.has_node("Sign"), id + " distinct model for " + item.id)
			if id == "laundry":
				game.use_mechanism("drain")
				var visual = world.get_node("Drain/Visual")
				await frames(12)
				check(visual.active and visual.amount > 0, "drain turn responds to real progress")
				var age: float = visual.feedback_age
				game.use_mechanism("drain")
				check(visual.feedback_age == age, "rejected repeated valve use does not replay feedback")
				game.restore_checkpoint(0)
				check(not visual.active and visual.amount == 0, "checkpoint restores valve pose immediately")
				game.use_mechanism("drain")
				game.use_mechanism("cart_ready")
				check(world.get_node("PressurePlate").feedback_age == 0, "pressure plate activation plays mechanical feedback")
				world.get_node("PressurePlate").position.y = 2.6
				game.restore_checkpoint(0)
				check(is_equal_approx(world.get_node("PressurePlate").position.y, world.get_node("Lift").position.y), "plate follows reset lift before fade-in")
				check(world.get_node("PressurePlate").position.y >= 0, "depressed pressure plate stays above floor")
				check(not world.get_node("Steam52").has_node("Caption"), "steam uses pressure gauge instead of countdown text")
			if id == "thread_vault":
				game.use_mechanism("bell")
				await frames(8)
				game.use_mechanism("bell")
				check(world.get_node("Bell/Visual").feedback_age == 0 and game.keeper.distraction > 0, "repeated bell swing preserves distraction")
			game.restore_checkpoint(2)
			for item in world.get_children():
				if item.has_method("sync_visual"):
					check(item.get_node("Visual").active == game.flags.get(item.id, false), "checkpoint restores " + id + "/" + item.id)
		game.queue_free()
		await frames(4)
	OS.delay_msec(120)
	print("MECHANICAL PROP FAILURES: ", failures)
	quit(1 if failures else 0)

extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func run() -> void:
	var game = load("res://scenes/chapters/full/workshop.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	game.start_game()
	await frames(4)
	check(game.ui.objective.text == game.rooms[0].spec.objective, "first objective states goal without revealing concealed fuse route")
	check(game.ui.hint.text.contains("提示"), "HUD exposes voluntary hint entry")
	game.player.set_physics_process(false)
	var room = game.rooms[0]
	var actor = game.player
	var control = actor.get_node("Interactions")
	actor.position = Vector3(16, .03, -.7)
	await frames(3)
	control.refresh_target()
	check(control.current_target == room.objects.hatch and not control.prompt_text.is_empty(), "reachable locked hatch explains prerequisite")
	var spare = load("res://scripts/puzzles/carry_item.gd").new()
	spare.item_kind = "gear"
	room.add_child(spare)
	room.objects["spare"] = spare
	spare.set_held(true)
	control.carried = spare
	actor.position = Vector3(12, .03, -.7)
	await frames(3)
	control.refresh_target()
	check(control.current_target == room.objects.fuse_socket, "wrong part still selects socket feedback")
	Input.action_press("interact")
	actor.set_physics_process(true)
	await frames(2)
	Input.action_release("interact")
	actor.set_physics_process(false)
	check(control.carried == spare and spare.held, "blocked socket interaction never drops carried part")
	control.carried = null
	room.objects.erase("spare")
	spare.queue_free()
	room.objects.crate.position.x = 3
	await frames(3)
	check(game.ui.objective.text == room.spec.objective, "discovery leaves next reasoning step to player")
	var fuse = room.objects.fuse
	fuse.attach_to_socket(room.objects.fuse_socket)
	room.objects.fuse_socket.occupied = fuse
	await frames(3)
	check(game.ui.objective.text == room.spec.objective, "supplied fuse does not turn HUD into solution checklist")
	room.objects.hatch.state = 1
	await frames(3)
	check(game.ui.objective.text.contains("向右"), "solved room gives explicit exit direction")
	game.restore_checkpoint("room_1")
	await frames(3)
	check(game.ui.objective.text == game.rooms[0].spec.objective, "checkpoint reset restores room goal")
	game.queue_free()
	await frames(4)
	game = load("res://scenes/chapters/full/thread_vault.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.start_game()
	game.set_process(false)
	room = game.rooms[3]
	room.objects.hoist.state = 1
	game.player.reset_to(room.position + Vector3(2, .03, 0))
	check(room.stage_objective() == room.spec.objective, "freight objective states cargo destination")
	room.objects.weight.set_held(true)
	game.player.get_node("Interactions").carried = room.objects.weight
	check(room.stage_objective() == room.spec.objective, "carrying weight keeps freight route in voluntary hints")
	game.queue_free()
	await frames(4)
	game = load("res://scenes/chapters/full/clocktower.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.start_game()
	game.set_process(false)
	game.active_room = 2
	room = game.rooms[2]
	room.objects.brake_a.state = 1
	room.objects.brake_a.timer = 4.2
	game.refresh_brake_status()
	check(game.ui.mechanism_status.text.contains("4.2"), "remaining brake time remains visible away from interaction prompt")
	room.objects.brake_a.timer = 0
	game.refresh_brake_status()
	check(game.ui.mechanism_status.text.contains("重新启动"), "expired brake gives recovery guidance")
	game.queue_free()
	await frames(4)
	quit(1 if failures else 0)

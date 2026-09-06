extends SceneTree
const TestInput = preload("res://tests/input_events.gd")

var game
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1
func frames(n: int) -> void:
	for i in range(n):
		await physics_frame
func move_x(target: float, action: String = "run", limit: int = 1600) -> void:
	TestInput.press("right" if target > game.player.position.x else "left")
	if action != "":
		TestInput.press(action)
	for i in range(limit):
		await physics_frame
		if absf(game.player.position.x - target) < .12 or game.respawning or not game.playing:
			break
	TestInput.release("right")
	TestInput.release("left")
	if action != "":
		TestInput.release(action)
	await frames(6)
func depth(target: float) -> void:
	var action := "depth_down" if target > game.player.position.z else "depth_up"
	TestInput.press(action)
	for i in range(150):
		await physics_frame
		if absf(game.player.position.z - target) < .06:
			break
	TestInput.release(action)
	await frames(6)
func interact() -> void:
	TestInput.press("interact")
	await frames(2)
	TestInput.release("interact")
	await frames(3)
func open_level(id: String) -> void:
	if game:
		game.queue_free()
		await frames(3)
	game = load("res://scenes/chapters/" + id + ".tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.start_game()
	await frames(12)

func run() -> void:
	await open_level("laundry")
	await move_x(6.7)
	await interact()
	check(game.flags.get("drain", false), "laundry drain through real interaction")
	await move_x(20.1)
	check(game.rules.checkpoint == 1, "drained channel reaches checkpoint")
	TestInput.press("interact")
	await move_x(24.25, "", 600)
	TestInput.release("interact")
	var cart = game.world.get_node("PushCrate")
	var hit := KinematicCollision3D.new()
	var lifted: Transform3D = cart.global_transform
	lifted.origin.y += .05
	print("LIFT ", game.world.get_node("Lift").position, " collider=", game.world.get_node("Lift").get_child(1).position)
	if cart.test_move(lifted, Vector3(.05, 0, 0), hit):
		print("LIFTED COLLISION ", hit.get_collider().name, " at=", hit.get_position(), " normal=", hit.get_normal())
	for i in range(cart.get_slide_collision_count()):
		print("CART CONTACT ", cart.get_slide_collision(i).get_collider().name, " normal=", cart.get_slide_collision(i).get_normal(), " at=", cart.get_slide_collision(i).get_position())
	check(game.flags.get("cart_ready", false), "cart physically reaches lift plate")
	await depth(-1.1)
	await interact()
	check(game.flags.get("fill", false), "loaded lift can be filled from deck")
	await frames(210)
	print("LIFT RIDER ", game.player.position, " cart=", game.world.get_node("PushCrate").position)
	check(game.player.position.y > 2.4, "AnimatableBody lift carries player to upper floor")
	await move_x(31)
	check(game.rules.checkpoint == 2, "upper walkway records laundry checkpoint")
	# Exercise all canonical restores, including repeated failures and active hazards.
	for id in ["laundry", "thread_vault", "clocktower"]:
		await open_level(id)
		for cp in range(3):
			game.restore_checkpoint(cp)
			game.fail()
			await frames(115)
			check(not game.respawning and game.player.enabled and game.rules.checkpoint == cp, id + " death restores checkpoint " + str(cp))
			game.fail()
			await frames(115)
			check(not game.respawning and game.player.enabled, id + " repeated death remains playable " + str(cp))
	await open_level("thread_vault")
	await move_x(5.1)
	TestInput.press("interact")
	await move_x(9.25, "", 650)
	TestInput.release("interact")
	check(game.flags.get("counterweight", false), "spool physically activates counterweight")
	await depth(1.2)
	await frames(200)
	await move_x(20.7)
	await depth(-.6)
	await interact()
	check(game.flags.get("winch_a", false), "first winch accessible after bridge")
	await frames(200)
	await move_x(30.7)
	await interact()
	check(game.flags.get("winch_b", false), "second winch builds last bridge")
	await frames(200)
	await move_x(40)
	check(game.rules.checkpoint == 2, "three bridges traverse to vault checkpoint")
	await open_level("clocktower")
	await move_x(6.7)
	await interact()
	await move_x(18)
	check(game.rules.checkpoint == 1 and not game.respawning, "brake permits timed pendulum crossing")
	await move_x(23.7)
	await depth(-1.1)
	await interact()
	check(game.flags.get("wind", false), "clock lift winds through interaction")
	await frames(210)
	check(game.player.position.y > 2.4, "clock lift carries player")
	await move_x(31.2)
	await interact()
	check(game.flags.get("release", false), "upper bell release starts final chase")
	await move_x(35)
	check(game.rules.checkpoint == 2, "final chase checkpoint saves bell state")
	game.queue_free()
	await frames(4)
	OS.delay_msec(120)
	print("EXPANSION FAILURES: ", failures)
	quit(1 if failures else 0)

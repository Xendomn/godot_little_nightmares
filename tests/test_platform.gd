extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var platform = load("res://scripts/chapters/moving_platform.gd").new()
	platform.position = Vector3(4, 0, 0)
	platform.travel = Vector3(0, 2.6, 0)
	platform.duration = 1
	root.add_child(platform)
	platform.activate()
	for i in range(40):
		await physics_frame
	var halfway: Vector3 = platform.position
	paused = true
	for i in range(10):
		await process_frame
	var stable: bool = platform.position.is_equal_approx(halfway)
	paused = false
	for i in range(80):
		await physics_frame
	var arrived: bool = platform.position.is_equal_approx(Vector3(4, 2.6, 0))
	platform.reset_platform()
	print("RESET actual=", platform.position, " origin=", platform.origin)
	var reset: bool = platform.position.is_equal_approx(Vector3(4, 0, 0)) and not platform.active
	platform.queue_free()
	await process_frame
	print("PLATFORM pause=", stable, " arrive=", arrived, " restore=", reset)
	quit(0 if stable and arrived and reset else 1)

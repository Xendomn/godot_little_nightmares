extends SceneTree
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count): await process_frame
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/props-" + name + ".png")
func run() -> void:
	var views := {
		"workshop": [["fuse-box", Vector3(30.7, .8, -.9)], ["power-switch", Vector3(51, .8, -.9)], ["shipping-chute", Vector3(87.5, 1.6, -.95)]],
		"laundry": [["drain", Vector3(7, .75, -.65)], ["cart", Vector3(21, .5, 0)], ["fill", Vector3(24.4, .8, -1.2)], ["steam", Vector3(52, 3.2, -1.8)], ["laundry-exit", Vector3(63, 4.4, -1)]],
		"thread_vault": [["spool-carrier", Vector3(6, .5, 0)], ["winch", Vector3(21, .8, -.7)], ["bell", Vector3(41, .75, .9)], ["vault-exit", Vector3(63, 1.8, -1)]],
		"clocktower": [["brake", Vector3(7, .8, -.6)], ["wind", Vector3(24, .8, -1.2)], ["release", Vector3(31.5, 3.4, -.65)], ["last-bell", Vector3(31.5, 6.8, -1)], ["clock-exit", Vector3(70, 4.4, -1)]]}
	for id in views:
		var game = load("res://scenes/chapters/" + id + ".tscn").instantiate()
		root.add_child(game)
		await frames(4)
		game.start_game()
		game.set_process(false)
		game.keeper.active = false
		game.player.enabled = false
		game.ui.hide()
		for view in views[id]:
			var center: Vector3 = view[1]
			game.player.position = Vector3(center.x - 1.2, 2.6 if center.y > 2 else 0, .2)
			game.camera.set_process(true)
			game.camera.instant = true
			await frames(35)
			await capture(view[0] + "-wide")
			game.camera.set_process(false)
			var large: bool = str(view[0]).contains("exit") or view[0] in ["shipping-chute", "last-bell"]
			game.camera.position = center + (Vector3(2, 1.5, 7) if large else Vector3(1.1, .8, 3.2))
			game.camera.look_at(center)
			await frames(20)
			await capture(view[0] + "-detail")
			print("CAPTURED PROP ", view[0])
		game.queue_free()
		await frames(4)
	OS.delay_msec(120)
	quit()

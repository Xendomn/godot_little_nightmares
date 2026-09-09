extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var chapter=load("res://scenes/chapters/full/thread_vault.tscn").instantiate()
	chapter.managed=true
	root.add_child(chapter)
	chapter.start_game()
	chapter.set_process(false)
	chapter.player.set_physics_process(false)
	chapter.keeper.set_physics_process(false)
	chapter.active_room=4
	var room=chapter.rooms[4]
	chapter.player.position=room.position+Vector3(17,.03,1.3)
	chapter.update_encounter(room,.1)
	check(chapter.keeper.visible,"guard is visibly present before bell is required")
	room.objects.bell.state=1
	room.objects.bell.timer=12
	chapter.keeper.position=room.position+Vector3(16,.03,-.8)
	chapter.update_encounter(room,.5)
	check(chapter.keeper.position.x<room.position.x+16 and chapter.keeper.position.x>room.position.x+9,"guard walks toward sound rather than teleporting to bell")
	check(chapter.keeper.position.z<-.8,"sound draws guard into rear investigation lane")
	room.objects.bell.timer=0
	var before: float=chapter.keeper.position.x
	chapter.update_encounter(room,.5)
	check(chapter.keeper.position.x>before,"guard resumes route when sound expires")
	room.objects.quiet_gate.state=1
	chapter.update_encounter(room,.5)
	check(not chapter.keeper.active,"upper safety gate ends encounter")
	chapter.free()
	await process_frame
	quit(1 if failures else 0)

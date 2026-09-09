extends SceneTree
var failures := 0
func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ")+label)
	if not value: failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var content = load("res://scripts/puzzles/campaign_content.gd")
	for id in content.IDS:
		var chapter = load("res://scenes/chapters/full/"+id+".tscn").instantiate()
		chapter.managed = true
		root.add_child(chapter)
		chapter.start_game()
		await physics_frame
		check(chapter.rooms.size()==6,id+" has six authored puzzle rooms")
		for room in chapter.rooms:
			check(not room.completed and not room.all_met(room.spec.goal),id+" / "+room.spec.title+" cannot skip causal goal")
			var snapshot: Dictionary = room.capture_state()
			for span in room.bridge_bodies: span.position.y = 2.0
			check(JSON.parse_string(JSON.stringify(snapshot)) is Dictionary,"snapshot is JSON-safe")
			for object in room.objects.values():
				if object.has_method("satisfied") and object.spec.kind == "latch": object.state = 1
				elif object is CharacterBody3D: object.position += Vector3(2,0,0)
			room.restore_state(snapshot)
			check(JSON.stringify(room.capture_state())==JSON.stringify(snapshot),"mechanisms and loose objects restore atomically")
		if id == "workshop":
			var lift_room = chapter.rooms[1]
			lift_room.objects.route.state = 1
			lift_room.machines.travel_target = 1
			chapter.player.reset_to(Vector3(63,.03,1.3))
			for _i in 120: await physics_frame
			lift_room.machines.travel_target = 0
			chapter.player.reset_to(Vector3(67,.03,0))
			for _i in 60: await physics_frame
			check(chapter.player.position.y > -.1 and lift_room.lift.position.y > 1.4,"descending lift holds above a player instead of crushing through floor")
			chapter.player.get_node("Interactions").carried = chapter.rooms[0].objects.fuse
			check(not chapter.rooms[4].objects.socket_a.can_interact(chapter.player),"foreign-room parts cannot create unresolved socket links")
			chapter.player.get_node("Interactions").carried = null
		chapter.free()
		await create_timer(.3,true,false,true).timeout
		await process_frame
	OS.delay_msec(150)
	quit(1 if failures else 0)

extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var hazard = load("res://scripts/puzzles/hazard_cycle.gd").new()
	var warned := 0.0
	for i in 600:
		hazard.time=float(i)*.01
		if hazard.hits_pendulum(Vector3(1.15,.02,0)): break
		if hazard.pendulum_stage()!="safe": warned+=.01
	check(warned>=1.0,"visible warning precedes possible standing contact by at least one second")
	hazard.time=5
	check(hazard.hits_pendulum(Vector3(0,.02,1.55)),"pendulum reaches the full player lane")
	var supports_height: bool=hazard.get_method_list().any(func(m): return m.name=="hits_pendulum" and m.args.size()==2)
	check(supports_height,"contact uses current player posture height")
	if supports_height: check(not hazard.hits_pendulum(Vector3(0,.02,0),.66),"crouched head below bob does not collide")
	var workshop = load("res://scenes/chapters/full/workshop.tscn").instantiate()
	workshop.managed=true
	root.add_child(workshop)
	var press=workshop.rooms[3]
	var support=press.objects.crate.get_node_or_null("LoadBearingFrame")
	check(support!=null,"support cart has a visible load bearing frame")
	if support:
		var bounds: AABB=support.transform*support.mesh.get_aabb()
		check(absf(bounds.end.y-1.725)<.03,"support geometry meets resting platen underside")
	workshop.free()
	var laundry=load("res://scenes/chapters/full/laundry.tscn").instantiate()
	laundry.managed=true
	root.add_child(laundry)
	var room=laundry.rooms[1]
	room.objects.crate.position.x=19
	room.objects.roof_hatch.state=1
	room.machines.water_machine.circuit.left=1.9
	room.machines.water_machine.refresh(0,true)
	check(room.objects.crate.buoyancy_target>1.6,"uncovered water has no invisible raft ceiling")
	var steam=laundry.rooms[5].machines.hazard_visuals[0].get_node("Steam")
	check(steam.mesh.size.z>=3.2,"steam visibly spans the full movement lane")
	laundry.free()
	await process_frame
	quit(1 if failures else 0)

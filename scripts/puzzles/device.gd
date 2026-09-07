extends Node3D
## A physical control; dependency expressions are evaluated by the owning room.
var object_id := ""
var spec: Dictionary
var room: Node3D
var state := 0
var timer := 0.0
var occupied: Node3D
var lamp: OmniLight3D

func _ready() -> void:
	add_to_group("puzzle_interactable")
	state = int(spec.get("initial", 0))
	lamp = OmniLight3D.new()
	lamp.position = Vector3(0,.4,.15)
	lamp.omni_range = 2.2
	lamp.light_energy = .6
	add_child(lamp)

func satisfied() -> bool:
	if spec.kind == "socket":
		return is_instance_valid(occupied) and occupied.socket_id == object_id
	if spec.kind == "plate":
		var total := 0.0
		for thing in room.objects.values():
			if thing is CharacterBody3D and "mass" in thing and not thing.get("held"):
				if absf(thing.global_position.x-global_position.x) < .85 and absf(thing.global_position.z-global_position.z) < 1.15 and absf(thing.global_position.y-room.global_position.y) < .6:
					total += thing.mass
		return total >= float(spec.get("mass",1.0))
	if spec.kind == "brake":
		return timer > 0
	return state > 0

func can_interact(actor: Node3D) -> bool:
	if spec.kind == "plate":
		return false
	if spec.kind == "socket":
		var carried = actor.get_node("Interactions").carried
		return room.all_met(spec.get("needs",[])) and ((carried != null and carried.item_kind == spec.accept and carried in room.objects.values() and not satisfied()) or satisfied() and carried == null)
	return room.all_met(spec.get("needs",[]))

func interact(actor: Node3D) -> void:
	if not can_interact(actor):
		return
	match spec.kind:
		"socket":
			var controller = actor.get_node("Interactions")
			if satisfied():
				if controller.release_socket(occupied): occupied = null
			else:
				occupied = controller.attach_carried(self)
		"selector": state = (state + 1) % int(spec.get("modes",3))
		"brake":
			state = 1
			timer = 12.0
		_: state = 1
	room.feedback("fuse_insert" if spec.kind == "socket" else "metal_latch")
	actor.visual_driver.play("interact", .35)

func get_prompt() -> String:
	var labels := {"selector":"切换档位", "socket":"取放部件", "brake":"制动 12 秒", "latch":"扳动门闩"}
	return "{interact} · " + str(labels.get(spec.kind,"互动")) + ("  [" + str(state) + "]" if spec.kind == "selector" else "")

func update(delta: float) -> void:
	timer = maxf(0,timer-delta)
	lamp.light_color = Color(.3, .95, .85) if satisfied() else Color(.95,.42,.12)
	var pivot = find_child("Lever", true, false)
	if pivot:
		pivot.rotation.z = lerp_angle(pivot.rotation.z, -.5 + state * .5, minf(1,delta*8))

func capture_state() -> Dictionary:
	return {"state":state,"timer":timer}
func restore_state(data: Dictionary) -> void:
	state = int(data.get("state",spec.get("initial",0)))
	timer = float(data.get("timer",0))
	occupied = null

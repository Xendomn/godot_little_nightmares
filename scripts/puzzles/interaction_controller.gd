extends Node
## Called by Player before locomotion so inputs have exactly one owner.
@export var reach: float = 1.65
var actor: CharacterBody3D
var current_target: Node3D
var carried: Node3D
var prompt_text := ""
var ladder: Node3D
var pushed: CharacterBody3D
var pickup_position := Vector3.ZERO
func _ready() -> void:
	actor = get_parent() as CharacterBody3D
func target_position(target: Node3D) -> Vector3:
	if target.has_method("interaction_position"):
		return target.interaction_position(actor)
	return target.global_position + Vector3(0, .25, 0)
func reachable(target: Node3D) -> bool:
	if not is_instance_valid(target) or not actor.get_parent().is_ancestor_of(target):
		return false
	var from := actor.global_position + Vector3(0, .6, 0)
	var to := target_position(target)
	if from.distance_to(to) > reach:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [actor.get_rid()]
	if is_instance_valid(carried):
		query.exclude.append(carried.get_rid())
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == target or target.is_ancestor_of(hit.collider)
func refresh_target() -> void:
	current_target = null
	var best := INF
	for candidate in get_tree().get_nodes_in_group("puzzle_interactable"):
		if candidate is Node3D and candidate.has_method("can_interact") and candidate.can_interact(actor) and reachable(candidate):
			var distance: float = (actor.global_position + Vector3(0, .6, 0)).distance_squared_to(target_position(candidate))
			if distance < best:
				current_target = candidate
				best = distance
	prompt_text = current_target.get_prompt() if current_target != null else ("{interact} · Place item" if carried != null else "")
func tick(delta: float) -> bool:
	if not actor.enabled:
		cancel_interaction()
		return false
	if is_instance_valid(ladder):
		prompt_text = "W/S · Climb   {interact} / {jump} · Let go"
		if InputHints.just_pressed("jump") or InputHints.just_pressed("interact"):
			ladder = null
			actor.velocity = Vector3.ZERO
			return false
		var vertical := Input.get_axis("depth_down", "depth_up")
		var next_y := clampf(actor.global_position.y + vertical * 1.8 * delta, ladder.global_position.y, ladder.global_position.y + ladder.height)
		actor.velocity = Vector3.ZERO
		actor.move_and_collide(Vector3(0, next_y - actor.global_position.y, 0))
		actor.animate_doll(delta, absf(vertical))
		return true
	if is_instance_valid(pushed):
		if not InputHints.pressed("interact") or not reachable(pushed):
			pushed.handler = null
			pushed = null
			actor.pushing = false
		else:
			pushed.move_with_actor(actor, Input.get_axis("left", "right"), delta)
			actor.velocity = Vector3(0, actor.velocity.y - 20 * delta, 0)
			actor.move_and_slide()
			actor.animate_doll(delta, absf(Input.get_axis("left", "right")))
			return true
	refresh_target()
	if InputHints.just_pressed("interact"):
		if current_target != null:
			current_target.interact(actor)
		elif carried != null:
			place_carried()
	if is_instance_valid(carried):
		carried.global_position = actor.global_position + Vector3(actor.facing * .48, .7, 0)
	return is_instance_valid(ladder) or is_instance_valid(pushed)
func pickup(item: Node3D) -> bool:
	if carried != null or ladder != null or not reachable(item):
		return false
	pickup_position = item.global_position
	item.detach_from_socket()
	item.set_held(true)
	carried = item
	return true
func place_carried() -> bool:
	if not is_instance_valid(carried):
		return false
	var destination := actor.global_position + Vector3(actor.facing * .85, .15, 0)
	var collision: CollisionShape3D = carried.get_node("CollisionShape3D")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.transform = Transform3D(carried.global_basis, destination) * collision.transform
	query.collision_mask = 1
	query.exclude = [actor.get_rid(), carried.get_rid()]
	if not actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	# The whole delivery path must be clear, not just the endpoint.
	var ray := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3(0,.65,0), destination + Vector3(0,.17,0), 1)
	ray.exclude = query.exclude
	if not actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return false
	carried.global_position = destination
	carried.set_held(false)
	carried = null
	return true
func attach_carried(socket: Node3D) -> Node3D:
	if not is_instance_valid(carried) or not reachable(socket):
		return null
	var item := carried
	item.attach_to_socket(socket)
	carried = null
	return item
func release_socket(item: Node3D) -> bool:
	return pickup(item)
func begin_push(target: CharacterBody3D) -> bool:
	if carried != null or ladder != null or not reachable(target):
		return false
	pushed = target
	target.handler = actor
	actor.pushing = true
	actor.velocity = Vector3.ZERO
	return true
func attach_ladder(target: Node3D) -> bool:
	if carried != null or not reachable(target):
		return false
	var destination := Vector3(target.global_position.x, actor.global_position.y, target.global_position.z)
	if actor.test_move(actor.global_transform, destination - actor.global_position):
		return false
	actor.global_position = destination
	actor.velocity = Vector3.ZERO
	ladder = target
	return true
func cancel_interaction() -> void:
	if is_instance_valid(carried):
		if not place_carried():
			carried.global_position = pickup_position
			carried.set_held(false)
			carried = null
	if is_instance_valid(pushed):
		pushed.handler = null
	pushed = null
	ladder = null
	current_target = null
	prompt_text = ""
	if is_instance_valid(actor):
		actor.pushing = false

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
var ladder_exiting := false
var ladder_returning := false
var just_left_ladder := false
var ladder_grip: SkeletonModifier3D
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
	var blocked_target: Node3D
	var blocked_distance := INF
	for candidate in get_tree().get_nodes_in_group("puzzle_interactable"):
		if candidate is Node3D and candidate.has_method("can_interact") and reachable(candidate):
			var distance: float = (actor.global_position + Vector3(0, .6, 0)).distance_squared_to(target_position(candidate))
			if candidate.can_interact(actor) and distance < best:
				current_target = candidate
				best = distance
			elif candidate.has_method("get_blocked_reason") and distance < blocked_distance:
				blocked_target = candidate
				blocked_distance = distance
	if current_target == null: current_target = blocked_target
	prompt_text = "{interact} · 放下物品" if carried != null else ""
	if current_target != null:
		prompt_text = current_target.get_prompt() if current_target.can_interact(actor) else current_target.display_name() + " · " + current_target.get_blocked_reason(actor)
func tick(delta: float) -> bool:
	if not actor.enabled:
		cancel_interaction()
		return false
	if is_instance_valid(ladder):
		prompt_text = "{vertical} · 攀爬   {interact} / {jump} · 松手"
		if InputHints.just_pressed("jump") or InputHints.just_pressed("interact"):
			detach_ladder()
			return false
		var vertical := Input.get_axis("depth_down", "depth_up")
		actor.velocity = Vector3.ZERO
		var before := actor.global_position
		if ladder_exiting:
			var target: Vector3 = ladder.to_global(ladder.top_exit)
			if vertical < -.05: ladder_returning = true
			if ladder_returning:
				target = Vector3(ladder.global_position.x,actor.global_position.y,ladder.global_position.z)
			var travel := target - actor.global_position
			# Check the entire remaining path before starting or continuing the transfer.
			if not actor.test_move(actor.global_transform, travel):
				actor.visual_driver.end_climb()
				actor.move_and_collide(travel.limit_length(delta * 2.4))
			else:
				prompt_text = "平台被挡住了 · {vertical} 攀爬 · {interact} 松手"
			if actor.global_position.distance_to(target) < .015:
				if ladder_returning:
					ladder_exiting = false
					ladder_returning = false
					actor.visual_driver.begin_climb()
				else:
					detach_ladder()
					return false
		else:
			var next_y := clampf(actor.global_position.y + vertical * 1.8 * delta, ladder.global_position.y, ladder.global_position.y + ladder.height)
			actor.move_and_collide(Vector3(0, next_y - actor.global_position.y, 0))
			if vertical > .05 and actor.global_position.y >= ladder.global_position.y + ladder.height - .005 and ladder.has_top_exit:
				ladder_exiting = true
			if vertical < -.05 and actor.global_position.y <= ladder.global_position.y + .005:
				detach_ladder()
				return false
		actor.model.rotation.y = ladder.facing_y
		if ladder_grip:
			ladder_grip.influence = clampf(1.0 - absf(actor.global_position.x-ladder.global_position.x)/.45,0,1)
		actor.visual_driver.advance_climb(actor.global_position.distance_to(before) / 1.8)
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
			if current_target.can_interact(actor):
				current_target.interact(actor)
			elif current_target.has_method("get_blocked_reason"):
				actor.get_parent().ui.notice(current_target.get_blocked_reason(actor), 3)
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
	if actor.global_position.y < target.global_position.y - .03 or actor.global_position.y > target.global_position.y + target.height + .03:
		return false
	var destination := Vector3(target.global_position.x, actor.global_position.y, target.global_position.z)
	if actor.test_move(actor.global_transform, destination - actor.global_position):
		return false
	var standing := CapsuleShape3D.new()
	standing.radius = .25
	standing.height = 1.2
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = standing
	clearance.transform = Transform3D(Basis.IDENTITY,destination+Vector3(0,.62,0))
	clearance.collision_mask = 1
	clearance.exclude = [actor.get_rid()]
	if not actor.get_world_3d().direct_space_state.intersect_shape(clearance,1).is_empty(): return false
	actor.global_position = destination
	actor.velocity = Vector3.ZERO
	actor.running = false
	actor.crouching = false
	(actor.collider.shape as CapsuleShape3D).height = 1.2
	actor.collider.position.y = .62
	ladder = target
	just_left_ladder = false
	ladder_exiting = false
	ladder_returning = false
	actor.model.rotation.y = target.facing_y
	actor.visual_driver.begin_climb()
	if not ladder_grip and actor.visual_driver.skeleton:
		ladder_grip = preload("res://scripts/puzzles/ladder_grip.gd").new()
		ladder_grip.controller = self
		actor.visual_driver.skeleton.add_child(ladder_grip)
	if ladder_grip:
		ladder_grip.active = true
		ladder_grip.influence = 1
	return true
func detach_ladder() -> void:
	ladder = null
	just_left_ladder = true
	ladder_exiting = false
	ladder_returning = false
	actor.velocity = Vector3.ZERO
	actor.visual_driver.end_climb()
	if ladder_grip: ladder_grip.active = false
func cancel_interaction() -> void:
	if is_instance_valid(carried):
		if not place_carried():
			carried.global_position = pickup_position
			carried.set_held(false)
			carried = null
	if is_instance_valid(pushed):
		pushed.handler = null
	pushed = null
	if is_instance_valid(ladder): detach_ladder()
	ladder = null
	ladder_exiting = false
	ladder_returning = false
	current_target = null
	prompt_text = ""
	if is_instance_valid(actor):
		actor.pushing = false

extends Node
## Owns imported rig playback. Translation/collision remain in CharacterBody3D.

var visual: Node3D
var animator: AnimationPlayer
var skeleton: Skeleton3D
var tree: AnimationTree
var machine: AnimationNodeStateMachine
var playback: AnimationNodeStateMachinePlayback
var spring: SpringBoneSimulator3D
var clips: Dictionary = {}
var current: String = ""
var locked_time := 0.0
var head_bone := -1
var crouch_moving := false
var climbing := false
var saved_process_mode := AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE

func setup(model: Node3D) -> void:
	visual = model
	animator = find_type(model, "AnimationPlayer")
	skeleton = find_type(model, "Skeleton3D")
	if not animator:
		return
	for full_name in animator.get_animation_list():
		var name: String = str(full_name).get_slice("/", str(full_name).get_slice_count("/") - 1)
		clips[name] = full_name
		if name in ["idle", "walk", "run", "crouch_walk", "listen", "chase", "carry_idle", "carry_walk", "pull", "climb"]:
			animator.get_animation(full_name).loop_mode = Animation.LOOP_LINEAR
		else:
			animator.get_animation(full_name).loop_mode = Animation.LOOP_NONE
	tree = AnimationTree.new()
	tree.name = "RigAnimationTree"
	visual.add_child(tree)
	tree.anim_player = tree.get_path_to(animator)
	machine = AnimationNodeStateMachine.new()
	for name in clips:
		if name == "RESET":
			continue
		var state := AnimationNodeAnimation.new()
		state.animation = clips[name]
		machine.add_node(name, state)
	for source in clips:
		for target in clips:
			if source != target and source != "RESET" and target != "RESET":
				var transition := AnimationNodeStateMachineTransition.new()
				transition.xfade_time = 0.13
				machine.add_transition(source, target, transition)
	tree.tree_root = machine
	tree.active = true
	playback = tree.get("parameters/playback")
	if skeleton:
		head_bone = skeleton.find_bone("Head")
		if skeleton.find_bone("ClothRoot") >= 0 and skeleton.find_bone("ClothTip") >= 0:
			spring = SpringBoneSimulator3D.new()
			spring.name = "ClothInertia"
			# Blend a restrained secondary motion over the authored folds. Full
			# influence can twist the broad hem during deep crouch transitions.
			spring.influence = 0.12
			skeleton.add_child(spring)
			spring.setting_count = 1
			spring.set_root_bone_name(0, "ClothRoot")
			spring.set_end_bone_name(0, "ClothTip")
			spring.set_stiffness(0, 2.0)
			spring.set_drag(0, 0.95)
			spring.set_gravity(0, 0.08)
	play("idle")

func find_type(node: Node, type: String) -> Node:
	if node.is_class(type):
		return node
	for child in node.get_children():
		var found = find_type(child, type)
		if found:
			return found
	return null

func _process(delta: float) -> void:
	locked_time = maxf(0, locked_time - delta)

func play(name: String, duration: float = 0.0) -> void:
	if not playback or not clips.has(name) or (locked_time > 0 and duration <= 0):
		return
	if current != name:
		if current.is_empty():
			playback.start(name)
		else:
			playback.travel(name)
		current = name
	locked_time = duration

func update_motion(speed: float, grounded: bool, crouching: bool, pushing: bool, vertical: float) -> void:
	if not grounded:
		play("jump" if vertical > 0 else "fall")
	elif pushing:
		play("push")
	elif crouching:
		if speed > 0.25:
			crouch_moving = true
		elif speed < 0.10:
			crouch_moving = false
		play("crouch_walk" if crouch_moving else "crouch")
	else:
		crouch_moving = false
		play("run" if speed > 3.2 else ("walk" if speed > 0.15 else "idle"))

func begin_climb() -> void:
	if not tree or not clips.has("climb"): return
	if not climbing: saved_process_mode = tree.callback_mode_process
	climbing = true
	locked_time = 0
	playback.start("climb")
	current = "climb"
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.advance(0)

func advance_climb(elapsed: float) -> void:
	if climbing and tree and elapsed > 0:
		tree.advance(elapsed)

func end_climb() -> void:
	if not climbing: return
	climbing = false
	if tree: tree.callback_mode_process = saved_process_mode
	locked_time = 0
	play("idle")

func reset_pose() -> void:
	end_climb()
	crouch_moving = false
	locked_time = 0
	current = ""
	play("idle")
	if spring:
		spring.reset()

func head_position(fallback: Vector3) -> Vector3:
	if skeleton and head_bone >= 0:
		return skeleton.global_transform * skeleton.get_bone_global_pose(head_bone).origin
	return fallback

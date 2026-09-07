extends SkeletonModifier3D
## Constrain the animated hands to real rungs without stretching arm bones.
var controller: Node
var contacts: Array[Vector3] = []
var targets: Array[Vector3] = []
func _process_modification() -> void:
	contacts.clear()
	targets.clear()
	if not is_instance_valid(controller) or not is_instance_valid(controller.ladder): return
	var ladder: Node3D = controller.ladder
	var rig := get_skeleton()
	for side in ["L","R"]:
		var hand := rig.find_bone("Hand."+side)
		var elbow := rig.find_bone("Forearm."+side)
		var shoulder := rig.find_bone("UpperArm."+side)
		if hand < 0 or elbow < 0 or shoulder < 0: continue
		var animated := rig.global_transform * rig.get_bone_global_pose(hand).origin
		var local := ladder.to_local(animated)
		var rung_y := clampf(.25 + roundf((local.y-.25)/.30)*.30, .25, 4.45)
		var goal := ladder.to_global(Vector3(.22 if side == "L" else -.22,rung_y,-.32))
		var local_goal := rig.to_local(goal)
		for iteration in range(12):
			for joint in [elbow,shoulder]:
				var pose := rig.get_bone_global_pose(joint)
				var current := rig.get_bone_global_pose(hand).origin-pose.origin
				var desired := local_goal-pose.origin
				if current.length_squared() < .000001 or desired.length_squared() < .000001: continue
				pose.basis = Basis(Quaternion(current.normalized(),desired.normalized())) * pose.basis
				rig.set_bone_global_pose(joint,pose)
		contacts.append(rig.global_transform * rig.get_bone_global_pose(hand).origin)
		targets.append(goal)

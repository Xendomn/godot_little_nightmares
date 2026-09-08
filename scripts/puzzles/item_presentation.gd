extends Node3D
## Local visual cues only: never bypass depth testing or interaction occlusion.
var item: CharacterBody3D
var pickup_light: OmniLight3D
func _ready() -> void:
	item = get_parent()
	var visual = item.get_node_or_null("Visual")
	if visual and item.item_kind == "fuse": visual.scale = Vector3.ONE
	if visual:
		for mesh in visual.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var original = mesh.get_active_material(surface)
				if not original is StandardMaterial3D: continue
				var mat: StandardMaterial3D = original.duplicate()
				# Preserve textures and authored colours, with a modest readable edge.
				mat.emission_enabled = true
				mat.emission = Color(.06,.20,.23) if item.item_kind == "fuse" else Color(.11,.085,.04)
				mat.emission_energy_multiplier = .45
				mesh.set_surface_override_material(surface, mat)
	pickup_light = OmniLight3D.new()
	pickup_light.name = "PickupLight"
	pickup_light.position.y = .3
	pickup_light.light_color = Color(.3,.8,.95) if item.item_kind == "fuse" else Color(1,.79,.43)
	pickup_light.light_energy = .8 if item.item_kind == "fuse" else .65
	pickup_light.omni_range = 1.8 if item.item_kind == "fuse" else 1.35
	pickup_light.shadow_enabled = false
	add_child(pickup_light)
	refresh()
func refresh() -> void:
	if pickup_light: pickup_light.visible = not item.held and not is_instance_valid(item.socket) and not item.concealed
func visual_bounds() -> AABB:
	var bounds := AABB()
	var first := true
	for mesh in item.get_node("Visual").find_children("*", "MeshInstance3D", true, false):
		var local: AABB = item.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
		bounds = local if first else bounds.merge(local)
		first = false
	return bounds

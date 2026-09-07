extends Node3D
## Legacy water_y is the centre of the old 8 cm surface slab.
## Keep that save convention; the visible surface is water_y + 0.04.
const BOTTOM := .005
var water_level := .1

func _ready() -> void:
	# Five outward-facing sides. The separately shaded surface closes the top.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var faces := [
		[Vector3(-8,0,2.05), Vector3(8,0,2.05), Vector3(8,1,2.05), Vector3(-8,1,2.05), Vector3.FORWARD * -1],
		[Vector3(8,0,-2.05), Vector3(-8,0,-2.05), Vector3(-8,1,-2.05), Vector3(8,1,-2.05), Vector3.FORWARD],
		[Vector3(8,0,2.05), Vector3(8,0,-2.05), Vector3(8,1,-2.05), Vector3(8,1,2.05), Vector3.RIGHT],
		[Vector3(-8,0,-2.05), Vector3(-8,0,2.05), Vector3(-8,1,2.05), Vector3(-8,1,-2.05), Vector3.LEFT],
		[Vector3(-8,0,-2.05), Vector3(8,0,-2.05), Vector3(8,0,2.05), Vector3(-8,0,2.05), Vector3.DOWN]
	]
	for face in faces:
		# Godot front faces use clockwise winding.
		for index in [0,2,1,0,3,2]:
			vertices.append(face[index])
			normals.append(face[4])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	$Volume.mesh = mesh
	set_water_level(water_level)

func set_water_level(level: float) -> void:
	water_level = clampf(level, -.05, 1.9)
	var top := water_level + .04
	var filled := top > BOTTOM + .001
	$Surface.visible = filled
	$Volume.visible = filled
	$Surface.position.y = top
	$Volume.position.y = BOTTOM
	$Volume.scale.y = maxf(top - BOTTOM, .001)

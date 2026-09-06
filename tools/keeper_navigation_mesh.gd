extends RefCounted
## Offline, ground-only nav mesh. Each cell is a navigable footprint for the
## existing capsule; furniture tops are never introduced as walking surfaces.
const CLEARANCE := 0.40
const HEIGHT := 3.4
const STEP := 0.25

static func attach(chapter: Node3D, id: String) -> void:
	var bounds: Rect2 = {
		"workshop": Rect2(29, -1.5, 24, 3),
		"laundry": Rect2(32, -1.5, 19, 3),
		"thread_vault": Rect2(40, -1.5, 19, 3),
		"clocktower": Rect2(28, -2.4, 44, 1)
	}[id]
	var floor_y := 2.6 if id in ["laundry", "clocktower"] else 0.0
	var obstacles: Array[Rect2] = []
	collect_obstacles(chapter.get_node("World"), Transform3D.IDENTITY, floor_y, obstacles)
	var mesh := NavigationMesh.new()
	mesh.agent_radius = CLEARANCE
	mesh.agent_height = HEIGHT
	mesh.cell_size = STEP
	mesh.cell_height = 0.25
	var vertices := PackedVector3Array()
	var indices: Dictionary = {}
	var polygons: Array[PackedInt32Array] = []
	var columns := ceili(bounds.size.x / STEP)
	var rows := ceili(bounds.size.y / STEP)
	for column in range(columns):
		for row in range(rows):
			var a := bounds.position + Vector2(column, row) * STEP
			var b := (a + Vector2.ONE * STEP).min(bounds.end)
			var cell := Rect2(a, b - a)
			var blocked := false
			for obstacle in obstacles:
				if cell.intersects(obstacle):
					blocked = true
					break
			if blocked:
				continue
			var polygon := PackedInt32Array()
			for corner in [Vector2i(column, row), Vector2i(column, row + 1), Vector2i(column + 1, row + 1), Vector2i(column + 1, row)]:
				if not indices.has(corner):
					indices[corner] = vertices.size()
					var point := (bounds.position + Vector2(corner) * STEP).min(bounds.end)
					vertices.append(Vector3(point.x, floor_y, point.y))
				polygon.append(indices[corner])
			polygons.append(polygon)
	mesh.vertices = vertices
	for polygon in polygons:
		mesh.add_polygon(polygon)
	var region := NavigationRegion3D.new()
	region.name = "KeeperNavigation"
	region.navigation_mesh = mesh
	chapter.add_child(region)

static func collect_obstacles(node: Node, parent_transform: Transform3D, floor_y: float, obstacles: Array[Rect2]) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform = parent_transform * node.transform
	if node is CollisionShape3D and node.get_parent() is StaticBody3D and not node.disabled and node.shape is BoxShape3D:
		var half: Vector3 = node.shape.size * .5
		var box := AABB(transform * -half, Vector3.ZERO)
		for x in [-1, 1]:
			for y in [-1, 1]:
				for z in [-1, 1]:
					box = box.expand(transform * (half * Vector3(x, y, z)))
		if box.end.y > floor_y + .08 and box.position.y < floor_y + HEIGHT:
			obstacles.append(Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z)).grow(CLEARANCE))
	for child in node.get_children():
		collect_obstacles(child, transform, floor_y, obstacles)

extends Resource
class_name LevelDefinition

@export var id: String = "workshop"
@export var title: String = "午夜工坊"
@export_file("*.tscn") var scene_path: String
@export var next_id: String
@export var camera_min: float = 6
@export var camera_max: float = 84
@export var checkpoint_positions: Array[Vector3] = []

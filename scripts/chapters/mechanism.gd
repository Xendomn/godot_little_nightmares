extends Node3D

signal used(id: String)
@export var id: String
@export var prompt: String = "{interact}  操作机关"
var chapter: Node3D

func get_prompt() -> String:
	if chapter and chapter.flags.get(id, false):
		return "机关已启动"
	return prompt if can_interact(null) else "需要先完成前面的机关"

func can_interact(_player: Node3D) -> bool:
	return chapter != null and chapter.mechanism_available(id)

func interact(player: Node3D) -> void:
	if can_interact(player):
		used.emit(id)

func sync_visual(immediate: bool = false) -> void:
	if chapter and has_node("Visual"):
		$Visual.set_active(chapter.flags.get(id, false), immediate)

func play_feedback() -> void:
	if has_node("Visual"):
		$Visual.play_feedback()

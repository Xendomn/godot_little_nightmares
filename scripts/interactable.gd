extends Node3D

signal used(kind: String)
@export_enum("fuse", "panel", "lever") var kind: String = "fuse"
var state: RefCounted
var time: float = 0.0

func get_prompt() -> String:
	match kind:
		"fuse": return "E  拾起保险丝"
		"panel": return "电路已接通" if state.power_on else ("E  装入保险丝" if state.has_fuse else ("电流正在等待开关" if state.fuse_installed else "这里缺少一枚保险丝"))
		"lever": return "电闸已经拉下" if state.power_on else ("E  拉下电闸" if state.fuse_installed else "配电箱还没有保险丝")
	return ""

func can_interact(_player: Node3D) -> bool:
	if not state:
		return false
	match kind:
		"fuse": return not state.has_fuse and not state.fuse_installed
		"panel": return state.has_fuse
		"lever": return state.fuse_installed and not state.power_on
	return false

func interact(player: Node3D) -> void:
	if not can_interact(player):
		return
	var changed := false
	match kind:
		"fuse": changed = state.collect_fuse()
		"panel": changed = state.install_fuse()
		"lever": changed = state.activate_power()
	if changed:
		used.emit(kind)
	refresh()

func refresh() -> void:
	if kind == "fuse":
		visible = not state.has_fuse and not state.fuse_installed

func _process(delta: float) -> void:
	time += delta
	if kind == "fuse" and has_node("Model"):
		$Model.position.y = 0.12 + sin(time * 2.0) * 0.07
		$Model.rotation.y += delta * 0.7

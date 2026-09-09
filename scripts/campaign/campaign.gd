extends Node
## Keeps only the active chapter in memory. All save paths are injectable for tests.

const Store = preload("res://scripts/campaign/save_store.gd")
const IDS := ["workshop", "laundry", "thread_vault", "clocktower"]
const TITLES := ["午夜工坊", "染洗间", "悬线库", "钟楼"]
@export var save_path: String = "user://campaign.json"
var store: RefCounted
var chapter: Node3D
var level_index := 0
var unlocked: Array = ["workshop"]
var saved: Dictionary = {}
var switching := false

func _ready() -> void:
	# Optional portable/QA save destination; explicit scene paths take precedence.
	var portable_save := OS.get_environment("MIDNIGHT_SAVE_PATH")
	if save_path == "user://campaign.json" and not portable_save.is_empty():
		save_path = portable_save
	store = Store.new(save_path)
	saved = store.read_campaign_checkpoint()
	if not saved.is_empty():
		unlocked = saved.unlocked.duplicate()
	load_chapter(0, null, false)
	if store.migration_failed:
		chapter.ui.notice("旧存档升级失败，原始进度已保留。请检查存档目录后重试。", 9)
	elif store.migrated:
		chapter.ui.notice("旧存档已备份：保留已解锁章节，从兼容的章节或房间起点继续。", 9)
	elif store.failed:
		chapter.ui.notice("存档无法读取，可以开始一段新旅程。", 7)
	elif store.recovered:
		chapter.ui.notice("已恢复上一份安全存档。", 7)

func load_chapter(index: int, checkpoint: Variant = null, begin: bool = true, snapshot: Dictionary = {}) -> void:
	get_tree().paused = false
	if chapter:
		remove_child(chapter)
		chapter.queue_free()
	level_index = clampi(index, 0, 3)
	var definition = load("res://resources/levels/" + IDS[level_index] + ".tres")
	chapter = load(definition.scene_path).instantiate()
	chapter.managed = true
	add_child(chapter)
	chapter.checkpoint_reached.connect(on_checkpoint)
	chapter.level_completed.connect(on_complete)
	var ui = chapter.ui
	ui.enable_campaign(not saved.is_empty() or store.migration_failed, unlocked)
	ui.start_requested.connect(start_new_journey)
	ui.continue_requested.connect(continue_journey)
	ui.chapter_selected.connect(select_chapter)
	ui.restart_requested.connect(replay_chapter)
	ui.checkpoint_retry_requested.connect(retry_checkpoint)
	ui.new_journey_requested.connect(start_new_journey)
	if begin:
		chapter.start_game()
		var stable_ids := chapter.get("checkpoint_id") is String
		if checkpoint == null:
			checkpoint = "room_1" if stable_ids else 0
		if stable_ids:
			chapter.restore_checkpoint(str(checkpoint), snapshot)
		else:
			chapter.restore_checkpoint(int(checkpoint) if not checkpoint is String else 0)
		chapter.ui.begin()
		write_save(checkpoint)
	switching = false

func start_new_journey() -> void:
	if not store.clear():
		chapter.ui.notice("无法清除旧存档，请检查存档目录权限。", 5)
		return
	saved = {}
	unlocked = ["workshop"]
	load_chapter(0)

func continue_journey() -> void:
	saved = store.read_campaign_checkpoint()
	if store.migration_failed:
		chapter.ui.notice("旧存档升级失败，原始进度已保留。", 7)
		return
	if saved.is_empty():
		chapter.ui.notice("没有可继续的存档。", 4)
		return
	unlocked = saved.unlocked.duplicate()
	var migration_notice: bool = store.migrated
	load_chapter(IDS.find(saved.level_id), saved.checkpoint_id, true, saved.flags)
	if migration_notice:
		chapter.ui.notice("旧存档已备份：保留已解锁章节，从兼容的章节或房间起点继续。", 9)

func select_chapter(index: int) -> void:
	if index >= 0 and index < IDS.size() and IDS[index] in unlocked:
		load_chapter(index)

func replay_chapter() -> void:
	load_chapter(level_index)

func retry_checkpoint() -> void:
	get_tree().paused = false
	chapter.ui.set_pause(false)
	chapter.fail()

func on_checkpoint(id: Variant) -> void:
	write_save(id)

func write_save(id: Variant) -> void:
	if store.write_checkpoint(IDS[level_index], id, unlocked, chapter.get_checkpoint_snapshot()):
		saved = store.read_checkpoint()
	else:
		chapter.ui.notice("本次进度仍可游玩，但自动存档写入失败。", 5)

func on_complete() -> void:
	if switching:
		return
	if level_index == 3:
		write_save(chapter.checkpoint_id if chapter.get("checkpoint_id") is String else 2)
		chapter.ui.ending.show()
		chapter.ui.focus_panel(chapter.ui.ending)
		return
	switching = true
	var next := level_index + 1
	if IDS[next] not in unlocked:
		unlocked.append(IDS[next])
	chapter.ui.notice("下一章 · " + TITLES[next], 2)
	var transition := create_tween()
	transition.tween_property(chapter.ui.fade, "color:a", 1.0, 0.8)
	transition.tween_interval(0.4)
	transition.tween_callback(func(): load_chapter(next))

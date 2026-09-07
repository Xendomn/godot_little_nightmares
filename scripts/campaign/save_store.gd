extends RefCounted

const LEVEL_IDS := ["workshop", "laundry", "thread_vault", "clocktower"]
const CHECKPOINT_IDS := ["room_1", "room_2", "room_3", "room_3_mid", "room_4", "room_5", "room_5_mid", "room_6", "room_6_mid"]
var migrated := false
var migration_failed := false
var path: String
var recovered: bool = false
var failed: bool = false

func _init(save_path: String = "user://campaign.json") -> void:
	path = save_path

func write_checkpoint(level_id: String, checkpoint_id: Variant, unlocked: Array, flags: Dictionary = {}) -> bool:
	if migration_failed:
		return false
	var data := {"version": 2 if checkpoint_id is String else 1, "level_id": level_id, "checkpoint_id": checkpoint_id, "unlocked": unlocked.duplicate(), "flags": flags.duplicate(true)}
	if not valid(data):
		return false
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	# Never replace a good backup with a damaged primary file.
	if not read_file(path).is_empty():
		if DirAccess.copy_absolute(absolute, absolute + ".bak") != OK:
			return false
	return DirAccess.rename_absolute(absolute + ".tmp", absolute) == OK

func read_checkpoint() -> Dictionary:
	recovered = false
	failed = false
	var current := read_file(path)
	if not current.is_empty():
		return current
	var backup := read_file(path + ".bak")
	if not backup.is_empty():
		recovered = true
		return backup
	failed = FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")
	return {}

func read_campaign_checkpoint() -> Dictionary:
	migrated = false
	migration_failed = false
	var data := read_checkpoint()
	if data.is_empty() or data.version == 2:
		return data
	# Archive the exact bytes from the valid source, including backup recovery.
	var source := path + ".bak" if recovered else path
	var original := FileAccess.get_file_as_bytes(source)
	var archive := path + ".v1.bak"
	if FileAccess.file_exists(archive):
		if FileAccess.get_file_as_bytes(archive) != original:
			migration_failed = true
			return {}
	elif DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(archive)) != OK:
		migration_failed = true
		return {}
	if not write_checkpoint(data.level_id, "room_1", data.unlocked, {}):
		migration_failed = true
		return {}
	migrated = true
	return read_file(path)

func clear() -> bool:
	var ok := true
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			ok = DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix)) == OK and ok
	if ok:
		migration_failed = false
	return ok

func read_file(filename: String) -> Dictionary:
	if not FileAccess.file_exists(filename):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(filename)) != OK:
		return {}
	var data = parser.data
	return data if data is Dictionary and valid(data) else {}

func valid(data: Dictionary) -> bool:
	if (data.get("version") != 1 and data.get("version") != 2) or data.get("level_id") not in LEVEL_IDS:
		return false
	var checkpoint = data.get("checkpoint_id")
	if data.version == 1:
		if not (checkpoint is int or checkpoint is float) or checkpoint != int(checkpoint) or checkpoint < 0 or checkpoint > 2:
			return false
	elif not checkpoint is String or checkpoint not in CHECKPOINT_IDS:
		return false
	var unlocked = data.get("unlocked")
	if not unlocked is Array or "workshop" not in unlocked or data.level_id not in unlocked:
		return false
	if unlocked.size() > LEVEL_IDS.size():
		return false
	for index in range(unlocked.size()):
		if unlocked[index] != LEVEL_IDS[index]:
			return false
	return data.get("flags") is Dictionary and json_safe(data.flags)

func json_safe(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return false
	if value == null or value is bool or value is String or value is StringName or value is int:
		return true
	if value is float:
		return is_finite(value)
	if value is Array:
		for item in value:
			if not json_safe(item, depth + 1): return false
		return true
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName) or not json_safe(value[key], depth + 1): return false
		return true
	return false

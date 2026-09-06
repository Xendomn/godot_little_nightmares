extends RefCounted

const LEVEL_IDS := ["workshop", "laundry", "thread_vault", "clocktower"]
var path: String
var recovered: bool = false
var failed: bool = false

func _init(save_path: String = "user://campaign.json") -> void:
	path = save_path

func write_checkpoint(level_id: String, checkpoint_id: int, unlocked: Array, flags: Dictionary = {}) -> bool:
	var data := {"version": 1, "level_id": level_id, "checkpoint_id": checkpoint_id, "unlocked": unlocked.duplicate(), "flags": flags.duplicate(true)}
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

func clear() -> bool:
	var ok := true
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			ok = DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix)) == OK and ok
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
	if data.get("version") != 1 or data.get("level_id") not in LEVEL_IDS:
		return false
	var checkpoint = data.get("checkpoint_id")
	if not (checkpoint is int or checkpoint is float) or checkpoint != int(checkpoint) or checkpoint < 0 or checkpoint > 2:
		return false
	var unlocked = data.get("unlocked")
	if not unlocked is Array or "workshop" not in unlocked or data.level_id not in unlocked:
		return false
	if unlocked.size() > LEVEL_IDS.size():
		return false
	for index in range(unlocked.size()):
		if unlocked[index] != LEVEL_IDS[index]:
			return false
	return data.get("flags") is Dictionary

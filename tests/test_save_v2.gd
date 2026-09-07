extends SceneTree

var failures := 0
var test_path := "res://artifacts/save-v2-test.json"
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1
func _initialize() -> void:
	var store = load("res://scripts/campaign/save_store.gd").new(test_path)
	store.clear()
	if FileAccess.file_exists(test_path + ".v1.bak"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + ".v1.bak"))
	check(store.has_method("read_campaign_checkpoint"), "explicit campaign migration API exists")
	if not store.has_method("read_campaign_checkpoint"):
		quit(1)
		return
	var snapshot := {"completed_rooms": [1, 2], "objects": {"fuse": {"socket": "lift", "position": [1, 2, 3]}}}
	for id in ["room_1", "room_2", "room_3", "room_3_mid", "room_4", "room_5", "room_5_mid", "room_6", "room_6_mid"]:
		check(store.write_checkpoint("workshop", id, ["workshop"], snapshot), "write stable checkpoint " + id)
		var loaded: Dictionary = store.read_checkpoint()
		check(loaded.version == 2 and loaded.checkpoint_id == id and loaded.flags == JSON.parse_string(JSON.stringify(snapshot)), "v2 snapshot roundtrip " + id)
	check(store.write_checkpoint("workshop", "room_6_mid", ["workshop"], {&"crate": {"name": &"box"}}), "Godot interned string keys and values serialize as JSON strings")
	check(not store.write_checkpoint("workshop", "room_7", ["workshop"]), "unknown stable checkpoint rejected")
	check(not store.write_checkpoint("workshop", "room_1", ["workshop"], {"bad": Vector3.ONE}), "non-JSON snapshot rejected")
	var corrupt := FileAccess.open(test_path, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	check(store.read_campaign_checkpoint().checkpoint_id == "room_6_mid" and store.recovered, "v2 damaged primary recovers valid snapshot backup")
	store.clear()
	check(store.write_checkpoint("thread_vault", 2, ["workshop", "laundry", "thread_vault"], {"old": true}), "legacy write supported")
	var original := FileAccess.get_file_as_bytes(test_path)
	check(store.read_checkpoint().version == 1, "legacy read never implicitly migrates")
	var migrated: Dictionary = store.read_campaign_checkpoint()
	check(migrated.get("version") == 2 and migrated.get("checkpoint_id") == "room_1" and migrated.get("flags") == {}, "campaign migration restarts chapter with fresh state")
	check(migrated.get("level_id") == "thread_vault" and migrated.get("unlocked") == ["workshop", "laundry", "thread_vault"], "migration retains active chapter and unlocks")
	check(store.migrated and not store.migration_failed, "migration notice state recorded")
	check(FileAccess.get_file_as_bytes(test_path + ".v1.bak") == original, "original v1 bytes archived")
	check(store.read_campaign_checkpoint().version == 2 and not store.migrated, "migration occurs only once")
	store.clear()
	# An existing different archive must never be replaced by another migration.
	store.write_checkpoint("laundry", 1, ["workshop", "laundry"])
	var conflicting := FileAccess.get_file_as_bytes(test_path)
	check(store.read_campaign_checkpoint().is_empty() and store.migration_failed, "conflicting migration archive safely blocks migration")
	check(FileAccess.get_file_as_bytes(test_path) == conflicting, "failed migration leaves primary untouched")
	check(FileAccess.get_file_as_bytes(test_path + ".v1.bak") == original, "failed migration leaves archive untouched")
	check(not store.write_checkpoint("workshop", "room_1", ["workshop"]), "failed migration blocks automatic overwrites")
	store.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + ".v1.bak"))
	print("SAVE V2 FAILURES: ", failures)
	quit(1 if failures else 0)

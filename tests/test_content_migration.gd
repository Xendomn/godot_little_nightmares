extends SceneTree

const Store = preload("res://scripts/campaign/save_store.gd")
const BASE := "res://artifacts/content-migration-test"
var failures := 0

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1

func write_bytes(filename: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(filename, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true

func remove_path(filename: String) -> void:
	var absolute := ProjectSettings.globalize_path(filename)
	if FileAccess.file_exists(filename) or DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute(absolute)

func cleanup(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".v1.bak", ".content-v1.bak", ".content-v1.1.bak", ".content-v1.2.bak"]:
		remove_path(path + suffix)

func world_flags(revision: Variant = null) -> Dictionary:
	var flags := {
		"rooms": {"4": {"completed": false, "objects": {"lift": {"state": 1}}}},
		"spawn": [190.0, 0.08, 0.0],
		"carrying": [4, "gear"],
	}
	if revision != null:
		flags["content_revision"] = revision
	return flags

func old_save_bytes(checkpoint: String = "room_5_mid", revision: Variant = null) -> PackedByteArray:
	var flags := world_flags(revision)
	var data := {
		"version": 2,
		"level_id": "thread_vault",
		"checkpoint_id": checkpoint,
		"unlocked": ["workshop", "laundry", "thread_vault"],
		"flags": flags,
	}
	return (" \n" + JSON.stringify(data, "  ") + "\n").to_utf8_buffer()

func test_old_world_snapshot_migrates_to_room_entrance() -> void:
	var path := BASE + "-old.json"
	cleanup(path)
	var original := old_save_bytes()
	check(write_bytes(path, original), "old world fixture written")
	var store = Store.new(path)
	var loaded: Dictionary = store.read_campaign_checkpoint()
	check(loaded.get("version") == 2 and loaded.get("checkpoint_id") == "room_5", "mid-room checkpoint migrates to the same room entrance")
	check(loaded.get("level_id") == "thread_vault" and loaded.get("unlocked") == ["workshop", "laundry", "thread_vault"], "content migration retains chapter and unlocks")
	check(loaded.get("flags", {}).size() == 1 and loaded.flags.get("content_revision") == 2, "incompatible world state is replaced by the current content revision")
	check(store.migrated and not store.migration_failed, "content migration records UI notice state")
	check(FileAccess.get_file_as_bytes(path + ".content-v1.bak") == original, "content migration archives exact original bytes")
	var migrated_bytes := FileAccess.get_file_as_bytes(path)
	var repeated: Dictionary = store.read_campaign_checkpoint()
	check(repeated == loaded and not store.migrated, "content migration runs only once")
	check(FileAccess.get_file_as_bytes(path) == migrated_bytes and not FileAccess.file_exists(path + ".content-v1.1.bak"), "repeated read neither rewrites the save nor creates another archive")
	cleanup(path)

func test_explicit_old_revision_migrates() -> void:
	var path := BASE + "-revision-one.json"
	cleanup(path)
	var original := old_save_bytes("room_3_mid", 1)
	check(write_bytes(path, original), "revision-one fixture written")
	var store = Store.new(path)
	var loaded: Dictionary = store.read_campaign_checkpoint()
	check(loaded.get("checkpoint_id") == "room_3" and loaded.get("flags", {}).size() == 1 and loaded.flags.get("content_revision") == 2, "explicit older world revision migrates to its room entrance")
	check(FileAccess.get_file_as_bytes(path + ".content-v1.bak") == original, "explicit older revision archives exact bytes")
	cleanup(path)

func test_current_world_snapshot_roundtrips_exactly() -> void:
	var path := BASE + "-current.json"
	cleanup(path)
	var store = Store.new(path)
	var flags := world_flags(2)
	check(store.write_checkpoint("clocktower", "room_6_mid", ["workshop", "laundry", "thread_vault", "clocktower"], flags), "current world snapshot written")
	var expected: Dictionary = store.read_checkpoint()
	var original := FileAccess.get_file_as_bytes(path)
	var loaded: Dictionary = store.read_campaign_checkpoint()
	check(loaded == expected and loaded.get("checkpoint_id") == "room_6_mid", "current content revision roundtrips without checkpoint changes")
	check(FileAccess.get_file_as_bytes(path) == original and not store.migrated, "current content revision read is non-mutating")
	check(not FileAccess.file_exists(path + ".content-v1.bak"), "current content revision creates no migration archive")
	cleanup(path)

func test_non_world_flags_are_not_migrated() -> void:
	var cases := [
		["empty", {}],
		["fixture", {"completed_rooms": [1, 2], "objects": {"fuse": {"socket": "lift"}}}],
	]
	for entry in cases:
		var path: String = BASE + "-" + entry[0] + ".json"
		cleanup(path)
		var store = Store.new(path)
		check(store.write_checkpoint("workshop", "room_2", ["workshop"], entry[1]), entry[0] + " non-world save written")
		var expected: Dictionary = store.read_checkpoint()
		var original := FileAccess.get_file_as_bytes(path)
		check(store.read_campaign_checkpoint() == expected and not store.migrated, entry[0] + " non-world flags remain compatible")
		check(FileAccess.get_file_as_bytes(path) == original and not FileAccess.file_exists(path + ".content-v1.bak"), entry[0] + " non-world read is non-mutating")
		cleanup(path)

func test_corrupt_primary_archives_recovered_backup_source() -> void:
	var path := BASE + "-recovery.json"
	cleanup(path)
	var original := old_save_bytes("room_6_mid")
	check(write_bytes(path + ".bak", original) and write_bytes(path, "{broken primary".to_utf8_buffer()), "recovery fixture written")
	var store = Store.new(path)
	var loaded: Dictionary = store.read_campaign_checkpoint()
	check(store.recovered and loaded.get("checkpoint_id") == "room_6", "corrupt primary migrates the valid backup to its room entrance")
	check(loaded.get("flags", {}).size() == 1 and loaded.flags.get("content_revision") == 2 and store.migrated, "recovered backup receives current content revision")
	check(FileAccess.get_file_as_bytes(path + ".content-v1.bak") == original, "recovery archives exact bytes from the valid backup source")
	check(FileAccess.get_file_as_bytes(path + ".bak") == original, "recovery leaves the valid safety backup untouched")
	cleanup(path)

func test_archive_collision_uses_numbered_file() -> void:
	var path := BASE + "-collision.json"
	cleanup(path)
	var original := old_save_bytes()
	var collision := "existing archive from another save".to_utf8_buffer()
	check(write_bytes(path, original) and write_bytes(path + ".content-v1.bak", collision), "archive collision fixture written")
	var store = Store.new(path)
	var loaded: Dictionary = store.read_campaign_checkpoint()
	check(loaded.get("flags", {}).size() == 1 and loaded.flags.get("content_revision") == 2 and store.migrated, "archive collision does not block content migration")
	check(FileAccess.get_file_as_bytes(path + ".content-v1.bak") == collision, "existing content archive is never overwritten")
	check(FileAccess.get_file_as_bytes(path + ".content-v1.1.bak") == original, "collision-safe numbered archive preserves exact original bytes")
	cleanup(path)

func test_archive_failure_preserves_original() -> void:
	var path := BASE + "-archive-failure.json"
	cleanup(path)
	var original := old_save_bytes()
	check(write_bytes(path, original), "archive failure fixture written")
	var archive_directory := ProjectSettings.globalize_path(path + ".content-v1.bak")
	check(DirAccess.make_dir_recursive_absolute(archive_directory) == OK, "blocking archive directory created")
	var store = Store.new(path)
	check(store.read_campaign_checkpoint().is_empty() and store.migration_failed, "archive write failure safely blocks content migration")
	check(FileAccess.get_file_as_bytes(path) == original, "archive failure leaves original primary bytes untouched")
	remove_path(path + ".content-v1.bak")
	cleanup(path)

func test_future_revision_fails_without_overwrite() -> void:
	var path := BASE + "-future.json"
	cleanup(path)
	var store = Store.new(path)
	check(store.write_checkpoint("laundry", "room_4", ["workshop", "laundry"], world_flags(3)), "future content fixture written")
	var original := FileAccess.get_file_as_bytes(path)
	check(store.read_checkpoint().get("flags", {}).get("content_revision") == 3, "ordinary read exposes future revision without mutation")
	check(store.read_campaign_checkpoint().is_empty() and store.migration_failed, "unknown future content revision fails campaign read safely")
	check(FileAccess.get_file_as_bytes(path) == original, "future revision primary is not overwritten")
	check(not FileAccess.file_exists(path + ".content-v1.bak"), "future revision creates no downgrade archive")
	check(not store.write_checkpoint("workshop", "room_1", ["workshop"], {"content_revision": 2}), "failed future revision blocks automatic overwrite")
	cleanup(path)

func _initialize() -> void:
	for revision in ["3", true, null]:
		var invalid_path := BASE + "-invalid-revision.json"
		cleanup(invalid_path)
		var invalid_store = Store.new(invalid_path)
		var flags: Dictionary = world_flags(2)
		flags.content_revision = revision
		invalid_store.write_checkpoint("workshop","room_3_mid",["workshop"],flags)
		var original := FileAccess.get_file_as_bytes(invalid_path)
		check(invalid_store.read_campaign_checkpoint().is_empty() and invalid_store.migration_failed,"nonnumeric content revision is not treated as old")
		check(FileAccess.get_file_as_bytes(invalid_path)==original and not FileAccess.file_exists(invalid_path+".content-v1.bak"),"unrecognized revision preserves original without archive")
		cleanup(invalid_path)
	test_old_world_snapshot_migrates_to_room_entrance()
	test_explicit_old_revision_migrates()
	test_current_world_snapshot_roundtrips_exactly()
	test_non_world_flags_are_not_migrated()
	test_corrupt_primary_archives_recovered_backup_source()
	test_archive_collision_uses_numbered_file()
	test_archive_failure_preserves_original()
	test_future_revision_fails_without_overwrite()
	print("CONTENT MIGRATION FAILURES: ", failures)
	quit(1 if failures else 0)

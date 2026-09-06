extends SceneTree

var failures := 0
var test_path := "res://artifacts/save-store-test.json"

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1

func _initialize() -> void:
	var store = load("res://scripts/campaign/save_store.gd").new(test_path)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(test_path + suffix):
			DirAccess.remove_absolute(test_path + suffix)
	check(store.read_checkpoint().is_empty(), "missing save returns no checkpoint")
	check(store.write_checkpoint("laundry", 1, ["workshop", "laundry"], {"drained": true}), "valid checkpoint is saved")
	var loaded: Dictionary = store.read_checkpoint()
	check(loaded.get("level_id") == "laundry" and loaded.get("checkpoint_id") == 1, "level and checkpoint survive reopening")
	check(loaded.get("flags", {}).get("drained") == true, "puzzle flags survive reopening")
	check(not store.write_checkpoint("unknown", 0, ["workshop"]), "unknown chapter is rejected")
	check(not store.write_checkpoint("workshop", 4, ["workshop"]), "out-of-bounds checkpoint is rejected")
	check(not store.write_checkpoint("clocktower", 0, ["workshop"]), "locked chapter cannot be saved as active")
	check(not store.write_checkpoint("clocktower", 0, ["workshop", "clocktower"]), "skipped chapter unlocks are rejected")
	check(not store.write_checkpoint("laundry", 0, ["workshop", "laundry", "laundry"]), "duplicate chapter unlocks are rejected")
	check(not store.write_checkpoint("laundry", 0, ["laundry", "workshop"]), "out-of-order unlocks are rejected")
	check(store.write_checkpoint("thread_vault", 0, ["workshop", "laundry", "thread_vault"]), "second save updates active chapter")
	var corrupt := FileAccess.open(test_path, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	loaded = store.read_checkpoint()
	check(store.recovered and loaded.get("level_id") == "laundry", "corrupted current save recovers previous valid backup")
	check(store.clear() and store.read_checkpoint().is_empty(), "new journey clears primary and backup progress")
	print("SAVE FAILURES: ", failures)
	quit(1 if failures else 0)

## Regression coverage for the local-co-op save boundary.
## Run: godot --headless --path . -s res://tests/adapters/inbound/test_local_coop_sandbox_snapshot.gd
extends SceneTree

const GAMEPLAY_SCENE := preload("res://src/adapters/inbound/gameplay/gameplay_runtime.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	var source := GAMEPLAY_SCENE.instantiate() as GameplayRuntime
	root.add_child(source)
	await process_frame
	source._session = Session.new("local_coop_snapshot", "adventure")
	source._local_inventory = {"wood_oak": 4, "ore_iron": 2, "sword_iron": 1}
	source.call("_setup_build_grid")
	var source_grid := source.get("_build_grid") as BuildGrid
	_expect(source_grid != null and source_grid.place_block(Vector3i(8, 1, -4), "brick_red"), "source sandbox accepts a placed creative block")
	var snapshot := source.get_sandbox_state()
	_expect(int(snapshot.inventory.get("sword_iron", 0)) == 1, "snapshot includes local fallback inventory without RulesRuntime")
	_expect(snapshot.placed_blocks.size() == 1, "snapshot includes shared build-grid state")

	var restored := GAMEPLAY_SCENE.instantiate() as GameplayRuntime
	root.add_child(restored)
	await process_frame
	restored.call("_setup_build_grid")
	restored.restore_sandbox_state(snapshot)
	await process_frame
	var restored_inventory: Dictionary = restored.get("_local_inventory") as Dictionary
	var restored_grid := restored.get("_build_grid") as BuildGrid
	_expect(int(restored_inventory.get("wood_oak", 0)) == 4 and int(restored_inventory.get("sword_iron", 0)) == 1, "restore preserves the local/co-op inventory fallback")
	_expect(restored_grid != null and restored_grid.has_block_at(Vector3i(8, 1, -4)), "restore preserves placed shared blocks")

	source.queue_free()
	restored.queue_free()
	await process_frame
	if _failures.is_empty():
		print("[test_local_coop_sandbox_snapshot] OK")
		quit(0)
	else:
		printerr("[test_local_coop_sandbox_snapshot] FAIL count=", _failures.size())
		quit(1)

extends SceneTree

const SPAWNER_3D := preload("res://src/adapters/inbound/gameplay/homestead_spawner_3d.gd")
const DYNAMIC_TRAITS := preload("res://src/domain/world_authoring/dynamic_npc_traits.gd")

var _failures: Array[String] = []


func _init() -> void:
	print("--- STARTING HOMESTEAD SPAWNER 3D ADAPTER TESTS ---")
	_test_spawner_lifecycle_and_compound_tree()

	if _failures.is_empty():
		print("[test_homestead_spawner_3d] ALL TESTS PASSED!")
		quit(0)
	else:
		printerr("[test_homestead_spawner_3d] FAILED WITH ", _failures.size(), " ERRORS: ", _failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		printerr("[FAIL] ", message)
	else:
		print("[PASS] ", message)


func _test_spawner_lifecycle_and_compound_tree() -> void:
	var spawner := SPAWNER_3D.new()
	root.add_child(spawner)

	var rng := RandomNumberGenerator.new()
	rng.seed = 999

	# Spawn Fisher Homestead
	var fisher_compound: Node3D = spawner.call("spawn_random_homestead", Vector3.ZERO, DYNAMIC_TRAITS.JobRole.FISHER, rng)
	_expect(fisher_compound != null, "Fisher compound should instantiate")
	_expect(fisher_compound.get_child_count() > 0, "Fisher compound should contain child nodes")

	var npc_found := false
	var vehicle_found := false
	var friendly_tool_ids := [
		"pitchfork", "rolling_pin", "watering_can", "fishing_rod",
		"hammer", "book", "paintbrush", "shepherd_crook"
	]

	for child in fisher_compound.get_children():
		if child.name.begins_with("NPC_"):
			npc_found = true
			_expect(child.has_meta("npc_id"), "NPC node should store metadata npc_id")
			_expect(child.has_meta("display_name"), "NPC node should store metadata display_name")
			_expect(child.has_meta("weapon_visual_id"), "NPC node should store metadata weapon_visual_id")
			var tool_meta := str(child.get_meta("weapon_visual_id"))
			_expect(tool_meta in friendly_tool_ids, "NPC metadata tool should be a friendly tool id")
			_expect(not tool_meta.contains(".glb"), "NPC metadata tool should not be a GLB path")
		elif child.name == "ParkedVehicle":
			vehicle_found = true

	_expect(npc_found, "NPC anchor node should exist inside compound")
	_expect(vehicle_found, "Parked vehicle node should exist inside fisher compound")

	# Spawn Farmer Homestead
	var farmer_compound: Node3D = spawner.call("spawn_random_homestead", Vector3.ZERO, DYNAMIC_TRAITS.JobRole.FARMER, rng)
	_expect(farmer_compound != null, "Farmer compound should instantiate")
	var specs: Array = spawner.call("get_spawned_specs")
	_expect(specs.size() == 2, "Spawner should track 2 spawned specs")

	spawner.queue_free()

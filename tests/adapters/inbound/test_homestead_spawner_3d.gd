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

	# Spawn Police Homestead
	var police_compound: Node3D = spawner.call("spawn_random_homestead", Vector3.ZERO, 3, rng) # 3 = POLICE_OFFICER
	_expect(police_compound != null, "Police compound should instantiate")
	_expect(police_compound.get_child_count() > 0, "Police compound should contain child nodes")

	var npc_found := false
	var vehicle_found := false

	for child in police_compound.get_children():
		if child.name.begins_with("NPC_"):
			npc_found = true
			_expect(child.has_meta("npc_id"), "NPC node should store metadata npc_id")
			_expect(child.has_meta("display_name"), "NPC node should store metadata display_name")
			_expect(str(child.get_meta("weapon_visual_id")).contains("pistol.glb"), "NPC metadata weapon should contain pistol.glb")
		elif child.name == "ParkedVehicle":
			vehicle_found = true

	_expect(npc_found, "NPC anchor node should exist inside compound")
	_expect(vehicle_found, "Parked vehicle node should exist inside police compound")

	# Spawn Farmer Homestead
	var farmer_compound: Node3D = spawner.call("spawn_random_homestead", Vector3.ZERO, 1, rng) # 1 = FARMER
	_expect(farmer_compound != null, "Farmer compound should instantiate")
	var specs: Array = spawner.call("get_spawned_specs")
	_expect(specs.size() == 2, "Spawner should track 2 spawned specs")

	spawner.queue_free()

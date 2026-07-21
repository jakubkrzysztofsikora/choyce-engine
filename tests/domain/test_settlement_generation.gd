extends SceneTree

const DYNAMIC_TRAITS := preload("res://src/domain/world_authoring/dynamic_npc_traits.gd")
const HOMESTEAD_SPEC := preload("res://src/domain/world_authoring/homestead_spec.gd")
const PLACEMENT_SERVICE := preload("res://src/adapters/inbound/gameplay/settlement_placement_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	print("--- STARTING SETTLEMENT GENERATION DOMAIN & SERVICE TESTS ---")
	_test_npc_traits_randomization_and_serialization()
	_test_homestead_spec_serialization()
	_test_settlement_placement_clustering()

	if _failures.is_empty():
		print("[test_settlement_generation] ALL TESTS PASSED!")
		quit(0)
	else:
		printerr("[test_settlement_generation] FAILED WITH ", _failures.size(), " ERRORS: ", _failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		printerr("[FAIL] ", message)
	else:
		print("[PASS] ", message)


func _test_npc_traits_randomization_and_serialization() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var farmer_traits := DYNAMIC_TRAITS.create_randomized("npc_farmer_1", DYNAMIC_TRAITS.JobRole.FARMER, rng)
	_expect(farmer_traits.npc_id == "npc_farmer_1", "NPC ID should map correctly")
	_expect(farmer_traits.job_role == DYNAMIC_TRAITS.JobRole.FARMER, "Role should be FARMER")
	_expect(farmer_traits.weapon_visual_id == "pitchfork", "Farmer tool should be pitchfork")
	_expect(not farmer_traits.weapon_visual_id.contains(".glb"), "Tool id should not be a GLB path")
	_expect(
		farmer_traits.vehicle_model_path.contains("civilian_car.glb") or farmer_traits.vehicle_model_path.contains("suv.glb"),
		"Farmer should get a civilian vehicle (civilian_car.glb or suv.glb)"
	)
	_expect(farmer_traits.openness >= 0.0 and farmer_traits.openness <= 1.0, "Openness should be clamped in [0.0, 1.0]")

	var dict := farmer_traits.to_dict()
	var roundtrip := DYNAMIC_TRAITS.from_dict(dict)
	_expect(roundtrip != null, "Dict deserialization should succeed")
	_expect(roundtrip.npc_id == "npc_farmer_1", "Roundtrip npc_id should match")
	_expect(roundtrip.display_name == farmer_traits.display_name, "Roundtrip display_name should match")
	_expect(roundtrip.job_role == DYNAMIC_TRAITS.JobRole.FARMER, "Roundtrip job_role should match")


func _test_homestead_spec_serialization() -> void:
	var spec := HOMESTEAD_SPEC.new(
		"home_123",
		"npc_farmer_1",
		"res://data/models/kaykit/builder/objects/house.gltf.glb",
		"res://data/models/vehicles/civilian_car.glb",
		["cow", "sheep"],
		Vector3(15.0, 0.0, 20.0),
		1.57,
		6.5
	)
	_expect(spec.homestead_id == "home_123", "Homestead ID should match")
	_expect(spec.animal_types.size() == 2, "Animal types count should be 2")

	var dict := spec.to_dict()
	var roundtrip := HOMESTEAD_SPEC.from_dict(dict)
	_expect(roundtrip != null, "HomesteadSpec roundtrip should succeed")
	_expect(roundtrip.position.distance_to(Vector3(15.0, 0.0, 20.0)) < 0.001, "Position vector should roundtrip cleanly")


func _test_settlement_placement_clustering() -> void:
	var service := PLACEMENT_SERVICE.new()
	var center := Vector3(0.0, 0.0, 0.0)
	var existing: Array[HOMESTEAD_SPEC] = []

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	for i in range(5):
		var spec_pos := service.find_valid_placement(center, existing, 10.0, 30.0, 6.0, rng)
		var spec := HOMESTEAD_SPEC.new("home_%d" % i, "npc_%d" % i, "", "", [], spec_pos)
		existing.append(spec)

	_expect(existing.size() == 5, "Should generate 5 clustered homestead placements")

	# Check that no two homesteads overlap under min distance
	for i in range(existing.size()):
		for j in range(i + 1, existing.size()):
			var d := Vector2(existing[i].position.x - existing[j].position.x, existing[i].position.z - existing[j].position.z).length()
			_expect(d >= 7.0, "Homesteads %d and %d should not overlap (d = %.2f)" % [i, j, d])

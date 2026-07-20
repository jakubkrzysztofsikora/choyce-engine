extends SceneTree

const GYM_SPAWNER_3D := preload("res://src/adapters/inbound/gameplay/gym_spawner_3d.gd")
const TRAINING_STATS := preload("res://src/domain/gameplay/training_stats.gd")

var _failures: Array[String] = []


func _init() -> void:
	print("--- STARTING GYM SPAWNER & BODY PROGRESSION TEST SUITE ---")
	_test_gym_spawner_instantiation()
	_test_equipment_stations_and_group_wiring()
	_test_workout_progression_logic()

	if _failures.is_empty():
		print("[test_gym_spawner_3d] ALL TESTS PASSED SUCCESSFULLY!")
		quit(0)
	else:
		printerr("[test_gym_spawner_3d] FAILED WITH ", _failures.size(), " ERRORS: ", _failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		printerr("[FAIL] ", message)
	else:
		print("[PASS] ", message)


func _test_gym_spawner_instantiation() -> void:
	var spawner := GYM_SPAWNER_3D.new()
	root.add_child(spawner)

	var compound: Node3D = spawner.spawn_gym(Vector3(-24.0, 0.0, 12.0))
	_expect(compound != null, "Gym compound should instantiate")
	_expect(compound.position == Vector3(-24.0, 0.0, 12.0), "Gym should be placed near player basecamp")
	_expect(compound.has_node("GymRubberFloor"), "Gym should have rubber foundation floor")
	_expect(compound.has_node("GymFloorBody"), "Gym should have solid collision body")

	spawner.queue_free()


func _test_equipment_stations_and_group_wiring() -> void:
	var spawner := GYM_SPAWNER_3D.new()
	root.add_child(spawner)

	var compound: Node3D = spawner.spawn_gym(Vector3(-24.0, 0.0, 12.0))
	var expected_stations := ["STRENGTH", "POSTURE", "STAMINA", "AGILITY", "FLEXIBILITY"]

	# New gym spawner attaches triggers directly to GLB equipment meshes.
	# Search the compound tree for Area3D nodes in world_interactable with
	# matching training_type_name meta.
	for station_variant in expected_stations:
		var station: String = String(station_variant)
		var found := false
		for area_variant in compound.find_children("*", "Area3D", true, false):
			var area := area_variant as Area3D
			if area == null:
				continue
			if not area.is_in_group("world_interactable"):
				continue
			var type_name := String(area.get_meta("training_type_name", ""))
			if type_name == station:
				found = true
				_expect(area.has_meta("resource_action"), "Area3D should store resource_action metadata for PlayerController")
				break
		_expect(found, "Gym should contain training station " + station + " (Area3D in world_interactable)")

	spawner.queue_free()


func _test_workout_progression_logic() -> void:
	var stats := TRAINING_STATS.new()
	var spawner := GYM_SPAWNER_3D.new().setup(stats)
	root.add_child(spawner)

	spawner.spawn_gym()

	_expect(stats.strength_level == 0, "Initial strength level should be 0")
	var res := spawner.perform_workout("STRENGTH")
	_expect(res["success"] == true, "Strength workout execution should succeed")
	_expect(res["progress"] == 0.25, "Strength progress should increase by 0.25")

	# Perform enough workouts to level up strength
	spawner.perform_workout("STRENGTH")
	spawner.perform_workout("STRENGTH")
	var lvl_res := spawner.perform_workout("STRENGTH")
	_expect(lvl_res["leveled_up"] == true or stats.strength_level > 0, "Strength stat should level up")

	spawner.queue_free()

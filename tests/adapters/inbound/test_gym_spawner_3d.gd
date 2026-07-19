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

	for station_variant in expected_stations:
		var station: String = String(station_variant)
		var node_name: String = "Station_" + station
		_expect(compound.has_node(node_name), "Gym should contain station " + node_name)

		var station_node: Node3D = compound.get_node(node_name) as Node3D
		var area: Area3D = station_node.get_node("TrainArea_" + station) as Area3D
		_expect(area != null, "Station should have Area3D trigger")
		_expect(area.is_in_group("world_interactable"), "Area3D trigger should belong to world_interactable group")
		_expect(area.has_meta("resource_action"), "Area3D should store resource_action metadata for PlayerController")

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

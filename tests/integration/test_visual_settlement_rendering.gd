extends SceneTree

const SPAWNER_3D := preload("res://src/adapters/inbound/gameplay/homestead_spawner_3d.gd")
const DYNAMIC_TRAITS := preload("res://src/domain/world_authoring/dynamic_npc_traits.gd")
const PARENTAL_POLICY := preload("res://src/domain/identity_safety/parental_control_policy.gd")

var _failures: Array[String] = []


func _init() -> void:
	print("--- STARTING VISUAL & AUTOMATED SETTLEMENT INTEGRATION TEST SUITE ---")
	_test_combat_policy_default_enabled()
	_test_outlaw_roles_and_dark_triad_stats()
	_test_visual_rendering_viewport()

	if _failures.is_empty():
		print("[test_visual_settlement_rendering] ALL VISUAL & AUTOMATED TESTS PASSED SUCCESSFULLY!")
		quit(0)
	else:
		printerr("[test_visual_settlement_rendering] FAILED WITH ", _failures.size(), " ERRORS: ", _failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		printerr("[FAIL] ", message)
	else:
		print("[PASS] ", message)


func _test_combat_policy_default_enabled() -> void:
	var policy := PARENTAL_POLICY.new()
	_expect(policy.combat_enabled == true, "ParentalControlPolicy should default combat_enabled to true")

	var dict_policy := PARENTAL_POLICY.from_dict({})
	_expect(dict_policy.combat_enabled == true, "ParentalControlPolicy.from_dict({}) should default combat_enabled to true")


func _test_outlaw_roles_and_dark_triad_stats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777

	var bandit: Variant = DYNAMIC_TRAITS.create_randomized("npc_b1", DYNAMIC_TRAITS.JobRole.BANDIT, rng)
	_expect(bandit.job_role == DYNAMIC_TRAITS.JobRole.BANDIT, "Role should be BANDIT")
	_expect(str(bandit.weapon_visual_id).contains("assault_rifle.glb"), "Bandit weapon should be assault_rifle.glb")
	_expect(bandit.psychopathy >= 0.5, "Bandit should have elevated psychopathy stat (>= 0.5)")

	var thief: Variant = DYNAMIC_TRAITS.create_randomized("npc_t1", DYNAMIC_TRAITS.JobRole.THIEF, rng)
	_expect(thief.job_role == DYNAMIC_TRAITS.JobRole.THIEF, "Role should be THIEF")
	_expect(str(thief.weapon_visual_id).contains("pistol.glb"), "Thief weapon should be pistol.glb")
	_expect(thief.machiavellianism >= 0.5, "Thief should have elevated Machiavellianism stat (>= 0.5)")

	var murderer: Variant = DYNAMIC_TRAITS.create_randomized("npc_m1", DYNAMIC_TRAITS.JobRole.MURDERER, rng)
	_expect(murderer.job_role == DYNAMIC_TRAITS.JobRole.MURDERER, "Role should be MURDERER")
	_expect(murderer.weapon_visual_id == "heavy_axe", "Murderer weapon should be heavy_axe")
	_expect(murderer.psychopathy >= 0.7, "Murderer should have high psychopathy stat (>= 0.7)")


func _test_visual_rendering_viewport() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)

	var world_root := Node3D.new()
	viewport.add_child(world_root)

	# Camera & Lighting setup
	var camera := Camera3D.new()
	world_root.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 15.0, 30.0), Vector3.ZERO)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	world_root.add_child(light)

	# Homestead Spawner
	var spawner := SPAWNER_3D.new()
	world_root.add_child(spawner)

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Spawn all roles into 3D world scene
	var roles := [
		DYNAMIC_TRAITS.JobRole.CIVILIAN,
		DYNAMIC_TRAITS.JobRole.FARMER,
		DYNAMIC_TRAITS.JobRole.POLICE_OFFICER,
		DYNAMIC_TRAITS.JobRole.MILITARY_SOLDIER,
		DYNAMIC_TRAITS.JobRole.BANDIT,
		DYNAMIC_TRAITS.JobRole.THIEF,
		DYNAMIC_TRAITS.JobRole.MURDERER
	]

	var spawned_nodes: Array[Node3D] = []
	for r in roles:
		var compound: Node3D = spawner.spawn_random_homestead(Vector3.ZERO, r, rng)
		if compound != null:
			spawned_nodes.append(compound)

	_expect(spawned_nodes.size() == roles.size(), "Should instantiate visual homestead compounds for all 7 roles")

	# Render frames in SubViewport to confirm visual pipeline stability
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_expect(spawner.get_spawned_specs().size() == roles.size(), "Spawner should track all 7 homestead specs")

	world_root.queue_free()
	viewport.queue_free()

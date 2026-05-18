extends ApplicationTest

const DeploymentConfigScn = preload("res://src/application/deployment_config.gd")
const FeatureFlagServiceScn = preload("res://src/application/feature_flag_service.gd")

func run() -> Dictionary:
	_test_deployment_modes()
	_test_mode_env_parsing()
	_test_feature_service()
	_test_hard_disabled_overrides()
	_test_environment_overrides()
	return _build_result("FeatureFlagService")

func _test_deployment_modes() -> void:
	var family_config = DeploymentConfigScn.new(DeploymentConfigScn.Mode.FAMILY_CLOUD)
	_assert_true(family_config.is_feature_enabled("online_multiplayer"), "FAMILY_CLOUD enables multiplayer")
	_assert_true(
		family_config.is_feature_enabled("online_family_sessions"),
		"FAMILY_CLOUD enables online family sessions"
	)
	_assert_true(family_config.is_feature_enabled("cloud_sync"), "FAMILY_CLOUD enables sync")
	_assert_false(
		family_config.is_feature_enabled("ai_experimental_tools"),
		"FAMILY_CLOUD keeps experimental AI disabled by default"
	)

	var local_config = DeploymentConfigScn.new(DeploymentConfigScn.Mode.LOCAL_ONLY)
	_assert_false(local_config.is_feature_enabled("online_multiplayer"), "LOCAL_ONLY disables multiplayer")
	_assert_false(local_config.is_feature_enabled("online_family_sessions"), "LOCAL_ONLY disables family sessions")
	_assert_false(local_config.is_feature_enabled("cloud_sync"), "LOCAL_ONLY disables sync")
	_assert_true(local_config.is_feature_enabled("ai_generation"), "LOCAL_ONLY keeps local AI generation")
	_assert_false(local_config.is_feature_enabled("telemetry"), "LOCAL_ONLY disables telemetry")

	var classroom_config = DeploymentConfigScn.new(DeploymentConfigScn.Mode.CLASSROOM)
	_assert_true(classroom_config.is_feature_enabled("ai_generation"), "CLASSROOM keeps AI generation")
	_assert_false(classroom_config.is_feature_enabled("online_multiplayer"), "CLASSROOM disables arbitrary multiplayer")
	_assert_false(classroom_config.is_feature_enabled("online_family_sessions"), "CLASSROOM disables family sessions")
	_assert_true(classroom_config.is_feature_enabled("cloud_sync"), "CLASSROOM enables managed sync")
	_assert_false(
		classroom_config.is_feature_enabled("ai_experimental_tools"),
		"CLASSROOM blocks experimental AI features"
	)


func _test_mode_env_parsing() -> void:
	var env_key := DeploymentConfigScn.ENV_VAR_MODE
	var previous_value := OS.get_environment(env_key)

	OS.set_environment(env_key, "local_only")
	var local_from_env = DeploymentConfigScn.from_environment()
	_assert_eq(local_from_env.mode, DeploymentConfigScn.Mode.LOCAL_ONLY, "local_only maps to LOCAL_ONLY")

	OS.set_environment(env_key, "classroom")
	var classroom_from_env = DeploymentConfigScn.from_environment()
	_assert_eq(classroom_from_env.mode, DeploymentConfigScn.Mode.CLASSROOM, "classroom maps to CLASSROOM")

	OS.set_environment(env_key, "family-cloud")
	var family_from_env = DeploymentConfigScn.from_environment()
	_assert_eq(family_from_env.mode, DeploymentConfigScn.Mode.FAMILY_CLOUD, "family-cloud maps to FAMILY_CLOUD")

	OS.set_environment(env_key, "unknown")
	var default_from_env = DeploymentConfigScn.from_environment()
	_assert_eq(default_from_env.mode, DeploymentConfigScn.Mode.FAMILY_CLOUD, "unknown mode defaults to FAMILY_CLOUD")

	OS.set_environment(env_key, previous_value)


func _test_feature_service() -> void:
	var base_config = DeploymentConfigScn.new(DeploymentConfigScn.Mode.LOCAL_ONLY)
	var service = FeatureFlagServiceScn.new(base_config)

	_assert_false(service.is_enabled("online_multiplayer"), "LOCAL_ONLY baseline disables multiplayer")

	var events: Array[String] = []
	service.feature_changed.connect(
		func(feature_key: String, enabled: bool) -> void:
			events.append("%s=%s" % [feature_key, "true" if enabled else "false"])
	)

	service.set_override("online_multiplayer", true)
	_assert_false(
		service.is_enabled("online_multiplayer"),
		"Hard-disabled deployment flag cannot be force-enabled by override"
	)

	service.set_override("online_multiplayer", false)
	_assert_false(service.is_enabled("online_multiplayer"), "Override can force-disable a feature")

	service.set_override("online_multiplayer", null)
	_assert_false(service.is_enabled("online_multiplayer"), "Clearing override restores deployment baseline")

	_assert_eq(events.size(), 3, "Feature changed emits on every override mutation")
	_assert_eq(events[0], "online_multiplayer=false", "First event resolves to enforced deployment safety")
	_assert_eq(events[2], "online_multiplayer=false", "Clearing override resolves to baseline false")


func _test_hard_disabled_overrides() -> void:
	var classroom_service = FeatureFlagServiceScn.new(
		DeploymentConfigScn.new(DeploymentConfigScn.Mode.CLASSROOM)
	)
	classroom_service.set_override("ai_experimental_tools", true)
	_assert_false(
		classroom_service.is_enabled("ai_experimental_tools"),
		"CLASSROOM hard-disable prevents enabling experimental AI"
	)

	var local_service = FeatureFlagServiceScn.new(
		DeploymentConfigScn.new(DeploymentConfigScn.Mode.LOCAL_ONLY)
	)
	local_service.set_override("online_family_sessions", true)
	_assert_false(
		local_service.is_enabled("online_family_sessions"),
		"LOCAL_ONLY hard-disable prevents enabling online family sessions"
	)

func _test_environment_overrides() -> void:
	var env_key := FeatureFlagServiceScn.ENV_VAR_OVERRIDES
	var previous_value := OS.get_environment(env_key)

	OS.set_environment(env_key, "{\"ai_experimental_tools\": true, \"telemetry\": false}")
	var json_override_service = FeatureFlagServiceScn.new(
		DeploymentConfigScn.new(DeploymentConfigScn.Mode.FAMILY_CLOUD)
	)
	_assert_true(json_override_service.is_enabled("ai_experimental_tools"), "JSON env override enables experimental AI")
	_assert_false(json_override_service.is_enabled("telemetry"), "JSON env override can disable telemetry")

	OS.set_environment(env_key, "cloud_sync=false,ai_beta_features=true")
	var csv_override_service = FeatureFlagServiceScn.new(
		DeploymentConfigScn.new(DeploymentConfigScn.Mode.FAMILY_CLOUD)
	)
	_assert_false(csv_override_service.is_enabled("cloud_sync"), "CSV env override can disable cloud sync")
	_assert_true(csv_override_service.is_enabled("ai_beta_features"), "CSV env override can enable beta features")

	# Test invalid input robustness
	OS.set_environment(env_key, "{not_valid_json")
	var robust_service = FeatureFlagServiceScn.new(
		DeploymentConfigScn.new(DeploymentConfigScn.Mode.LOCAL_ONLY)
	)
	# Should handle gracefully without crashing and likely set no overrides
	_assert_false(robust_service.is_enabled("online_multiplayer"), "Invalid config string is ignored gracefully")
	_assert_false(robust_service.is_enabled("online_family_sessions"), "Mode defaults remain enforced after invalid overrides")

	OS.set_environment(env_key, "online_multiplayer=true,online_family_sessions=true")
	var local_override_service = FeatureFlagServiceScn.new(
		DeploymentConfigScn.new(DeploymentConfigScn.Mode.LOCAL_ONLY)
	)
	_assert_false(
		local_override_service.is_enabled("online_multiplayer"),
		"CSV overrides cannot bypass local-only multiplayer lock"
	)
	_assert_false(
		local_override_service.is_enabled("online_family_sessions"),
		"CSV overrides cannot bypass local-only family-session lock"
	)

	OS.set_environment(env_key, previous_value)

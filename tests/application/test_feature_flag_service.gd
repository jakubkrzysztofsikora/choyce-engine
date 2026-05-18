extends ApplicationTest

const DeploymentConfigScn = preload("res://src/application/deployment_config.gd")
const FeatureFlagServiceScn = preload("res://src/application/feature_flag_service.gd")

## Minimal stub EnvironmentPort for tests — no adapter import allowed in application tests.
class StubEnvironmentPort:
	extends EnvironmentPort

	var _values: Dictionary = {}

	func set_value(key: String, value: String) -> void:
		_values[key] = value

	func get_env(key: String, default_value: String = "") -> String:
		return _values.get(key, default_value)


func run() -> Dictionary:
	_test_deployment_modes()
	_test_mode_env_parsing()
	_test_feature_service()
	_test_hard_disabled_overrides()
	_test_environment_overrides()
	_test_pre_setup_returns_base_config_and_warns_once()
	_test_setup_with_null_env_rejected()
	_test_setup_with_stub_applies_overrides()
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
	# Use setup() with empty stub — no env overrides, tests base-config behaviour.
	var stub := StubEnvironmentPort.new()
	var service = FeatureFlagServiceScn.new(base_config).setup(stub)

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
	var stub := StubEnvironmentPort.new()
	var classroom_service = FeatureFlagServiceScn.new(
		DeploymentConfigScn.new(DeploymentConfigScn.Mode.CLASSROOM)
	).setup(stub)
	classroom_service.set_override("ai_experimental_tools", true)
	_assert_false(
		classroom_service.is_enabled("ai_experimental_tools"),
		"CLASSROOM hard-disable prevents enabling experimental AI"
	)

	var local_service = FeatureFlagServiceScn.new(
		DeploymentConfigScn.new(DeploymentConfigScn.Mode.LOCAL_ONLY)
	).setup(stub)
	local_service.set_override("online_family_sessions", true)
	_assert_false(
		local_service.is_enabled("online_family_sessions"),
		"LOCAL_ONLY hard-disable prevents enabling online family sessions"
	)

func _test_environment_overrides() -> void:
	# Uses stub EnvironmentPort — no OSEnvironmentAdapter fallback in application layer.
	var config := DeploymentConfigScn.new(DeploymentConfigScn.Mode.FAMILY_CLOUD)

	# JSON override
	var stub_json := StubEnvironmentPort.new()
	stub_json.set_value(FeatureFlagServiceScn.ENV_VAR_OVERRIDES, '{"ai_experimental_tools": true, "telemetry": false}')
	var json_override_service = FeatureFlagServiceScn.new(config).setup(stub_json)
	_assert_true(json_override_service.is_enabled("ai_experimental_tools"), "JSON env override enables experimental AI")
	_assert_false(json_override_service.is_enabled("telemetry"), "JSON env override can disable telemetry")

	# CSV override
	var stub_csv := StubEnvironmentPort.new()
	stub_csv.set_value(FeatureFlagServiceScn.ENV_VAR_OVERRIDES, "cloud_sync=false,ai_beta_features=true")
	var csv_override_service = FeatureFlagServiceScn.new(config).setup(stub_csv)
	_assert_false(csv_override_service.is_enabled("cloud_sync"), "CSV env override can disable cloud sync")
	_assert_true(csv_override_service.is_enabled("ai_beta_features"), "CSV env override can enable beta features")

	# Invalid JSON falls back to csv parser; malformed csv pairs are skipped gracefully
	var stub_invalid := StubEnvironmentPort.new()
	stub_invalid.set_value(FeatureFlagServiceScn.ENV_VAR_OVERRIDES, "{not_valid_json")
	var local_config := DeploymentConfigScn.new(DeploymentConfigScn.Mode.LOCAL_ONLY)
	var robust_service = FeatureFlagServiceScn.new(local_config).setup(stub_invalid)
	_assert_false(robust_service.is_enabled("online_multiplayer"), "Invalid config string is ignored gracefully")
	_assert_false(robust_service.is_enabled("online_family_sessions"), "Mode defaults remain enforced after invalid overrides")

	# Hard-disable cannot be bypassed via CSV
	var stub_bypass := StubEnvironmentPort.new()
	stub_bypass.set_value(FeatureFlagServiceScn.ENV_VAR_OVERRIDES, "online_multiplayer=true,online_family_sessions=true")
	var local_override_service = FeatureFlagServiceScn.new(local_config).setup(stub_bypass)
	_assert_false(
		local_override_service.is_enabled("online_multiplayer"),
		"CSV overrides cannot bypass local-only multiplayer lock"
	)
	_assert_false(
		local_override_service.is_enabled("online_family_sessions"),
		"CSV overrides cannot bypass local-only family-session lock"
	)


## MUST: new WITHOUT setup — is_enabled returns base-config; push_warning fired (not crashing).
func _test_pre_setup_returns_base_config_and_warns_once() -> void:
	var base_config = DeploymentConfigScn.new(DeploymentConfigScn.Mode.LOCAL_ONLY)
	var service = FeatureFlagServiceScn.new(base_config)

	# Should not crash; returns base-config value (LOCAL_ONLY disables online_multiplayer).
	var result := service.is_enabled("online_multiplayer")
	_assert_false(result, "Pre-setup is_enabled returns base-config (LOCAL_ONLY disables multiplayer)")

	# Call a second time — warning must fire at most once (no exception thrown).
	var result2 := service.is_enabled("ai_generation")
	_assert_true(result2, "Pre-setup is_enabled returns correct base-config for ai_generation")

	# Overrides dict is empty so no override is in effect.
	_assert_false(service.is_enabled("cloud_sync"), "Pre-setup: no overrides applied, LOCAL_ONLY disables cloud_sync")


## MUST: setup(null) must push_error and NOT silently succeed.
func _test_setup_with_null_env_rejected() -> void:
	var service = FeatureFlagServiceScn.new(
		DeploymentConfigScn.new(DeploymentConfigScn.Mode.FAMILY_CLOUD)
	)
	# setup(null) should push_error and return self without wiring anything.
	var returned = service.setup(null)
	_assert_true(returned == service, "setup(null) returns self (does not crash)")
	# Service should still behave as pre-setup (no _env wired, _setup_called false).
	# ai_generation is enabled in FAMILY_CLOUD by default.
	var result := service.is_enabled("ai_generation")
	_assert_true(result, "After setup(null) rejection, base-config still queryable")


## MUST: new + setup with stub EnvironmentPort — overrides applied as expected.
func _test_setup_with_stub_applies_overrides() -> void:
	var config := DeploymentConfigScn.new(DeploymentConfigScn.Mode.FAMILY_CLOUD)
	var stub := StubEnvironmentPort.new()
	stub.set_value(FeatureFlagServiceScn.ENV_VAR_OVERRIDES, "advanced_debug=true,telemetry=false")

	var service = FeatureFlagServiceScn.new(config).setup(stub)
	_assert_true(service.is_enabled("advanced_debug"), "setup with stub: advanced_debug override applied true")
	_assert_false(service.is_enabled("telemetry"), "setup with stub: telemetry override applied false")
	# ai_generation not in override — should use config default (FAMILY_CLOUD enables it).
	_assert_true(service.is_enabled("ai_generation"), "setup with stub: non-overridden key uses config default")

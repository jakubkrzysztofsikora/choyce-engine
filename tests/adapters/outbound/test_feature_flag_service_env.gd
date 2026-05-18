## Tests for FeatureFlagService with a stub EnvironmentPort.
##
## MUST-1  setup(env) wires the port; get_env called during override loading
## MUST-2  JSON overrides string parsed and applied when env stub returns it
## MUST-3  comma-separated overrides parsed and applied when env stub returns them
## MUST-4  empty override string → no overrides applied, defaults from config used
## MUST-5  DeploymentConfig.from_environment(env) uses the supplied port
## MUST-6  FeatureFlagService constructed without setup() still functions (backward compat)
extends SceneTree


class StubEnv:
	extends EnvironmentPort

	var _values: Dictionary = {}

	func set_value(key: String, value: String) -> void:
		_values[key] = value

	func get_env(key: String, default_value: String = "") -> String:
		return _values.get(key, default_value)


func _init() -> void:
	var failures: Array[String] = []
	var checks := 0

	# MUST-6: backward compat — no setup(), OS.get_environment not called into application
	var svc_no_setup := FeatureFlagService.new()
	checks += 1
	if not svc_no_setup.has_method("is_enabled"):
		failures.append("MUST-6: FeatureFlagService must have is_enabled() after _init() only")
	checks += 1
	if not svc_no_setup.has_method("setup"):
		failures.append("MUST-6: FeatureFlagService must have setup() method")

	# MUST-4: stub returns empty string → no overrides, defaults apply
	var stub_empty := StubEnv.new()
	var config_default := DeploymentConfig.new(DeploymentConfig.Mode.FAMILY_CLOUD)
	var svc_empty := FeatureFlagService.new(config_default).setup(stub_empty)
	checks += 1
	# ai_generation defaults to true in FAMILY_CLOUD
	if not svc_empty.is_enabled("ai_generation"):
		failures.append("MUST-4: ai_generation should be enabled in FAMILY_CLOUD with empty env")
	checks += 1
	# advanced_debug defaults to false
	if svc_empty.is_enabled("advanced_debug"):
		failures.append("MUST-4: advanced_debug should be disabled with empty env")

	# MUST-2: JSON override string
	var stub_json := StubEnv.new()
	stub_json.set_value("CHOYCE_FEATURE_OVERRIDES", '{"ai_generation": false, "advanced_debug": true}')
	var svc_json := FeatureFlagService.new(config_default).setup(stub_json)
	checks += 1
	if svc_json.is_enabled("ai_generation"):
		failures.append("MUST-2: ai_generation must be false from JSON override")
	checks += 1
	if not svc_json.is_enabled("advanced_debug"):
		failures.append("MUST-2: advanced_debug must be true from JSON override")

	# MUST-3: comma-separated key=value override
	var stub_csv := StubEnv.new()
	stub_csv.set_value("CHOYCE_FEATURE_OVERRIDES", "ai_generation=false,advanced_debug=true")
	var svc_csv := FeatureFlagService.new(config_default).setup(stub_csv)
	checks += 1
	if svc_csv.is_enabled("ai_generation"):
		failures.append("MUST-3: ai_generation must be false from CSV override")
	checks += 1
	if not svc_csv.is_enabled("advanced_debug"):
		failures.append("MUST-3: advanced_debug must be true from CSV override")

	# MUST-5: DeploymentConfig.from_environment(stub) uses stub, not OS
	var stub_mode := StubEnv.new()
	stub_mode.set_value("CHOYCE_DEPLOYMENT_MODE", "classroom")
	var config_from_stub := DeploymentConfig.from_environment(stub_mode)
	checks += 1
	if config_from_stub.mode != DeploymentConfig.Mode.CLASSROOM:
		failures.append(
			"MUST-5: from_environment(stub) must return CLASSROOM mode, got: %s" % str(config_from_stub.mode)
		)

	var stub_local := StubEnv.new()
	stub_local.set_value("CHOYCE_DEPLOYMENT_MODE", "local_only")
	var config_local := DeploymentConfig.from_environment(stub_local)
	checks += 1
	if config_local.mode != DeploymentConfig.Mode.LOCAL_ONLY:
		failures.append(
			"MUST-5: from_environment(stub) must return LOCAL_ONLY mode, got: %s" % str(config_local.mode)
		)

	# MUST-1: setup() returns self (chainable) and wires env
	var stub_chain := StubEnv.new()
	stub_chain.set_value("CHOYCE_FEATURE_OVERRIDES", "advanced_debug=true")
	var svc_chain := FeatureFlagService.new(config_default)
	var returned := svc_chain.setup(stub_chain)
	checks += 1
	if returned != svc_chain:
		failures.append("MUST-1: setup() must return self for chaining")
	checks += 1
	if not svc_chain.is_enabled("advanced_debug"):
		failures.append("MUST-1: setup() must re-load overrides from the supplied env port")

	if failures.is_empty():
		print("[PASS] FeatureFlagServiceEnv (%d checks)" % checks)
		quit(0)
	else:
		print("[FAIL] FeatureFlagServiceEnv")
		for item in failures:
			print("  - %s" % item)
		quit(1)

extends SceneTree


class TestEnvironment:
	extends EnvironmentPort


func _init() -> void:
	var config := DeploymentConfig.new(DeploymentConfig.Mode.LOCAL_ONLY)
	var feature_flags := FeatureFlagService.new(config).setup(TestEnvironment.new())
	feature_flags.set_override("debug_test_bridge", true)
	var adapter := TestBridgeAdapter.new()
	adapter.setup(feature_flags, 0)

	var accepted := false
	if adapter.start():
		accepted = adapter.inject_input({
			"type": "action",
			"action_name": "ui_accept",
			"pressed": true,
		})
	adapter.stop()
	adapter.free()

	if accepted:
		print("[PASS] TestBridgeAdapter accepts action input")
		quit(0)
	else:
		print("[FAIL] TestBridgeAdapter must accept action input when enabled")
		quit(1)

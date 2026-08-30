extends SceneTree


class TestEnvironment:
	extends EnvironmentPort


class InspectableBridgeAdapter:
	extends TestBridgeAdapter

	var service_calls := 0

	func _service_connection(_connection: StreamPeerTCP) -> void:
		service_calls += 1


func _init() -> void:
	var failures: Array[String] = []
	_test_action_input(failures)
	_test_main_debug_bridge_gates_and_lifecycle(failures)
	_test_closed_connection_is_removed_before_read(failures)

	if failures.is_empty():
		print("[PASS] TestBridgeAdapter bridge wiring and input")
		quit(0)
	else:
		print("[FAIL] TestBridgeAdapter bridge wiring and input")
		for failure in failures:
			print("  - %s" % failure)
		quit(1)


func _test_action_input(failures: Array[String]) -> void:
	var config := DeploymentConfig.new(DeploymentConfig.Mode.LOCAL_ONLY)
	var feature_flags := FeatureFlagService.new(config).setup(TestEnvironment.new())
	feature_flags.set_override("debug_test_bridge", true)
	var adapter := TestBridgeAdapter.new()
	if not adapter is TestBridgePort:
		failures.append("TestBridgeAdapter must implement TestBridgePort")
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

	if not accepted:
		failures.append("TestBridgeAdapter must accept action input when enabled")


func _test_main_debug_bridge_gates_and_lifecycle(failures: Array[String]) -> void:
	var previous_debug_gate := OS.get_environment("CHOYCE_DEBUG_TEST_BRIDGE")
	var main := InboundMain.new()
	var config := DeploymentConfig.new(DeploymentConfig.Mode.LOCAL_ONLY)
	var feature_flags := FeatureFlagService.new(config).setup(TestEnvironment.new())

	feature_flags.set_override("debug_test_bridge", true)
	OS.set_environment("CHOYCE_DEBUG_TEST_BRIDGE", "0")
	main._feature_flags = feature_flags
	main._setup_debug_test_bridge()
	if main._test_bridge != null:
		failures.append("bridge must remain absent when the environment gate is off")

	OS.set_environment("CHOYCE_DEBUG_TEST_BRIDGE", "1")
	feature_flags.set_override("debug_test_bridge", false)
	main._setup_debug_test_bridge()
	if main._test_bridge != null:
		failures.append("bridge must remain absent when the feature flag is off")

	feature_flags.set_override("debug_test_bridge", true)
	main._setup_debug_test_bridge()
	var bridge = main._test_bridge
	if bridge == null:
		failures.append("bridge must start when both debug gates are enabled")
	else:
		if bridge.get_parent() != main:
			failures.append("started bridge must be attached to InboundMain")
		if not bridge._active:
			failures.append("bridge must start before it is polled")
		main._process(0.0)
		if not bridge._active:
			failures.append("started bridge must remain active after polling")
		main._teardown_debug_test_bridge()
		if bridge._active:
			failures.append("bridge teardown must stop the adapter")

	OS.set_environment("CHOYCE_DEBUG_TEST_BRIDGE", previous_debug_gate)
	main.free()


func _test_closed_connection_is_removed_before_read(failures: Array[String]) -> void:
	var adapter := InspectableBridgeAdapter.new()
	var closed_connection := StreamPeerTCP.new()
	adapter._http_server = TCPServer.new()
	adapter._active = true
	adapter._clients.append(closed_connection)

	adapter.poll()

	if adapter.service_calls != 0:
		failures.append("closed connections must not be serviced after polling")
	if not adapter._clients.is_empty():
		failures.append("closed connections must be removed during polling")
	adapter.free()

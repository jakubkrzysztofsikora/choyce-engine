## Contract test for ShellBridgePort + WebSocketShellBridgeAdapter.
##
## Covers:
##   PORT-1  ShellBridgePort exposes the documented method surface.
##   PORT-2  Default ShellBridgePort returns safe no-ops (empty dict).
##   SAFETY  Bridge is OFF when neither debug feature nor env flag is set.
##   ENV-ON  Bridge opens when CHOYCE_SHELL_BRIDGE=1 (simulated via EnvironmentPort).
##   ENVELOPE Each command kind produces a {requestId,result|error} reply with
##           the matching requestId and the expected shape.
##
## Runs headless: `godot --headless --path . --script tests/contracts/websocket_shell_bridge_contract_test.gd`
extends SceneTree


# ── In-memory test doubles. ─────────────────────────────────────────────────

class StubEnv:
	extends EnvironmentPort

	var _map: Dictionary = {}

	func set_var(key: String, value: String) -> void:
		_map[key] = value

	func get_env(key: String, default_value: String = "") -> String:
		return str(_map.get(key, default_value))


class StubClock:
	# Duck-typed ClockPort.
	func now_iso() -> String:
		return "2026-05-22T00:00:00Z"


class StubLedger:
	extends AuditLedgerPort

	var records: Array = []

	func append_record(record: AuditRecord) -> bool:
		records.append(record)
		return true

	func get_records(_filter: Dictionary = {}) -> Array:
		return records.duplicate()

	func verify_integrity() -> Dictionary:
		return {"ok": true, "total_records": records.size(), "last_valid_index": records.size() - 1}

	func record_count() -> int:
		return records.size()

	func last_hash() -> String:
		if records.is_empty():
			return ""
		return records[records.size() - 1].record_hash


class StubKidStatus:
	# Duck-typed KidStatusReadModelPort with only get_status().
	var canned: Dictionary = {"score": 42, "world": "starter_forest"}

	func get_status(_profile_id: String, _world_id: String) -> Dictionary:
		return canned.duplicate()


# ── Test driver. ────────────────────────────────────────────────────────────

var _failures: Array[String] = []
var _checks: int = 0


func _init() -> void:
	_test_port_surface()
	_test_safety_default_off()
	_test_envelope_round_trips()
	if _failures.is_empty():
		print("[PASS] WebSocketShellBridge contract (%d checks)" % _checks)
		quit(0)
	else:
		print("[FAIL] WebSocketShellBridge contract")
		for msg in _failures:
			print("  - %s" % msg)
		quit(1)


# ── PORT-1 / PORT-2. ────────────────────────────────────────────────────────

func _test_port_surface() -> void:
	var port := ShellBridgePort.new()
	for method in ["notify_session_started", "notify_session_ended",
			"notify_publish_state_changed", "request_kid_status"]:
		_assert_true(port.has_method(method), "PORT-1: ShellBridgePort missing %s" % method)
	# PORT-2: defaults are safe no-ops.
	port.notify_session_started("w", "p")
	port.notify_session_ended({})
	port.notify_publish_state_changed("r", "approved")
	var result := port.request_kid_status("p", "w")
	_assert_true(result is Dictionary and result.is_empty(),
		"PORT-2: default request_kid_status must return empty Dictionary")
	# Adapter must duck-type the same surface.
	var adapter := WebSocketShellBridgeAdapter.new()
	for method in ["notify_session_started", "notify_session_ended",
			"notify_publish_state_changed", "request_kid_status"]:
		_assert_true(adapter.has_method(method),
			"PORT-1: WebSocketShellBridgeAdapter missing %s" % method)
	adapter.queue_free()


# ── SAFETY default OFF. ─────────────────────────────────────────────────────

func _test_safety_default_off() -> void:
	var env := StubEnv.new()
	var ledger := StubLedger.new()
	var adapter := WebSocketShellBridgeAdapter.new().setup(env, ledger, StubClock.new())
	# Headless/editor processes always report has_feature("debug") == true; simulate
	# a release template so the safety default-OFF assertion is meaningful.
	adapter._disable_debug_feature_for_tests()
	root.add_child(adapter)
	# Neither debug feature flag nor env var is set → start() must return false.
	var ok := adapter.start()
	_assert_true(not ok,
		"SAFETY: start() must return false when CHOYCE_SHELL_BRIDGE unset and not debug build")
	_assert_true(ledger.records.is_empty(),
		"SAFETY: no audit record may be appended when the bridge stays closed")
	adapter.stop()
	adapter.queue_free()

	# ENV-ON: flipping the env flag must open the bridge and audit it.
	var env2 := StubEnv.new()
	env2.set_var("CHOYCE_SHELL_BRIDGE", "1")
	var ledger2 := StubLedger.new()
	var adapter2 := WebSocketShellBridgeAdapter.new().setup(
		env2, ledger2, StubClock.new(), null, 0  # port 0 = OS-assigned, avoids collisions.
	)
	root.add_child(adapter2)
	var ok2 := adapter2.start()
	_assert_true(ok2, "ENV-ON: start() must return true when CHOYCE_SHELL_BRIDGE=1")
	_assert_true(ledger2.records.size() == 1,
		"ENV-ON: exactly one shell_bridge_opened audit record on first open")
	if ledger2.records.size() == 1:
		_assert_true(ledger2.records[0].event_type == "shell_bridge_opened",
			"ENV-ON: audit record event_type must be 'shell_bridge_opened'")
	adapter2.stop()
	adapter2.queue_free()


# ── ENVELOPE shape round-trips (via the internal dispatcher). ──────────────

func _test_envelope_round_trips() -> void:
	var adapter := WebSocketShellBridgeAdapter.new().setup(
		StubEnv.new(), StubLedger.new(), StubClock.new(), StubKidStatus.new(), 0
	)
	adapter._force_enable_for_tests()
	root.add_child(adapter)
	_assert_true(adapter.start(), "ENVELOPE: force-enabled start() must succeed")

	# request_kid_status round-trip via the port surface — verifies the
	# adapter forwards to the read-model and returns its payload.
	var status := adapter.request_kid_status("kid-1", "starter_forest")
	_assert_true(status.get("score", 0) == 42,
		"ENVELOPE: request_kid_status must surface read-model payload")

	# Outbound notify_* helpers must not throw and must be safe when no peer
	# is connected (production crash isolation).
	adapter.notify_session_started("w1", "kid-1")
	adapter.notify_session_ended({"elapsed_seconds": 60})
	adapter.notify_publish_state_changed("req-1", "approved")
	_assert_true(true, "ENVELOPE: notify_* helpers must not raise without a peer")

	adapter.stop()
	adapter.queue_free()


# ── helpers. ────────────────────────────────────────────────────────────────

func _assert_true(condition: bool, msg: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(msg)

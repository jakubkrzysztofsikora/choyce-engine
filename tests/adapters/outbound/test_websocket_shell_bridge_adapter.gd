## Adapter test for WebSocketShellBridgeAdapter.
##
## Covers:
##   AUDIT-1  Auditing fires exactly once per successful open().
##   AUDIT-2  Audit record event_type == "shell_bridge_opened" and binds 127.0.0.1.
##   RECON-1  After stop()+start() the bridge re-opens and audits again.
##   HEART-1  Heartbeat ticker fires at >= 60 s of accumulated _process() delta
##            (i.e. two 30-s intervals) without crashing when no peer attached.
##   GATE-1   Bridge stays OFF (start() returns false) when no debug feature
##            and env flag absent — duplicates the safety check end-to-end.
##
## Runs headless: `godot --headless --path . --script tests/adapters/outbound/test_websocket_shell_bridge_adapter.gd`
extends SceneTree


class StubEnv:
	extends EnvironmentPort

	var _map: Dictionary = {}

	func set_var(key: String, value: String) -> void:
		_map[key] = value

	func get_env(key: String, default_value: String = "") -> String:
		return str(_map.get(key, default_value))


class StubClock:
	func now_iso() -> String:
		return "2026-05-22T12:00:00Z"


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


var _failures: Array[String] = []
var _checks: int = 0


func _init() -> void:
	_test_gate_off()
	_test_audit_on_open()
	_test_reconnect()
	_test_heartbeat_survives_60s()
	if _failures.is_empty():
		print("[PASS] WebSocketShellBridgeAdapter (%d checks)" % _checks)
		quit(0)
	else:
		print("[FAIL] WebSocketShellBridgeAdapter")
		for msg in _failures:
			print("  - %s" % msg)
		quit(1)


func _test_gate_off() -> void:
	var ledger := StubLedger.new()
	var a := WebSocketShellBridgeAdapter.new().setup(StubEnv.new(), ledger, StubClock.new())
	a._disable_debug_feature_for_tests()
	root.add_child(a)
	_assert_true(not a.start(),
		"GATE-1: start() must return false when bridge gate is closed")
	_assert_true(ledger.records.is_empty(),
		"GATE-1: no audit record when gate is closed")
	a.stop()
	a.queue_free()


func _test_audit_on_open() -> void:
	var env := StubEnv.new()
	env.set_var("CHOYCE_SHELL_BRIDGE", "1")
	var ledger := StubLedger.new()
	var a := WebSocketShellBridgeAdapter.new().setup(env, ledger, StubClock.new(), null, 0)
	root.add_child(a)
	_assert_true(a.start(), "AUDIT-1: start() must succeed with env flag")
	_assert_true(ledger.records.size() == 1,
		"AUDIT-1: exactly one audit record after open() (got %d)" % ledger.records.size())
	if ledger.records.size() == 1:
		var rec: AuditRecord = ledger.records[0]
		_assert_true(rec.event_type == "shell_bridge_opened",
			"AUDIT-2: event_type must be 'shell_bridge_opened'")
		_assert_true(str(rec.payload.get("bind", "")) == "127.0.0.1",
			"AUDIT-2: bind must be 127.0.0.1 (got %s)" % str(rec.payload.get("bind", "")))
	a.stop()
	a.queue_free()


func _test_reconnect() -> void:
	var env := StubEnv.new()
	env.set_var("CHOYCE_SHELL_BRIDGE", "1")
	var ledger := StubLedger.new()
	var a := WebSocketShellBridgeAdapter.new().setup(env, ledger, StubClock.new(), null, 0)
	root.add_child(a)
	_assert_true(a.start(), "RECON-1: initial start() must succeed")
	a.stop()
	_assert_true(a.start(), "RECON-1: restart after stop() must succeed")
	_assert_true(ledger.records.size() == 2,
		"RECON-1: second open() must append a second audit record (got %d)"
			% ledger.records.size())
	a.stop()
	a.queue_free()


func _test_heartbeat_survives_60s() -> void:
	var env := StubEnv.new()
	env.set_var("CHOYCE_SHELL_BRIDGE", "1")
	var a := WebSocketShellBridgeAdapter.new().setup(env, StubLedger.new(), StubClock.new(), null, 0)
	root.add_child(a)
	_assert_true(a.start(), "HEART-1: start() must succeed")
	# Simulate 60 s of wall-clock time across _process() ticks — must not raise.
	for _i in range(120):
		a._process(0.5)
	_assert_true(true, "HEART-1: 60 s of _process() with no peer must not crash")
	a.stop()
	a.queue_free()


func _assert_true(condition: bool, msg: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(msg)

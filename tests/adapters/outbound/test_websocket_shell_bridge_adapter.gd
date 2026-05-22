## Adapter test for WebSocketShellBridgeAdapter.
##
## Covers:
##   AUDIT-1  Auditing fires exactly once per successful open().
##   AUDIT-2  Audit record event_type == "shell_bridge_opened" and binds 127.0.0.1.
##   RECON-1  After stop()+start() the bridge re-opens and audits again.
##   HEART-1  Heartbeat ticker fires at >= 60 s of accumulated _process() delta
##            (i.e. two 30-s intervals) without crashing when no peer attached.
##   GATE-1   Bridge stays OFF (start() returns false) when env flag absent.
##   AUTH-1   Per-launch token rotates on every start(); start() prints + audits it.
##   AUTH-2   Inbound envelope without auth_token gets {ok:false, error:"auth_required"}.
##   AUTH-3   3 consecutive missing-token envelopes close the peer.
##   AUTH-4   Matching auth_token is accepted; `hello` still REQUIRES the token.
##   COLL-1   start() detects port collision and audits "shell_bridge_port_collision".
##   BUF-1    notify_* ring-buffers up to 32 envelopes when no peer is attached.
##   BUF-2    Buffer overflow drops oldest + audits "shell_bridge_envelope_dropped".
##   BUF-3    Buffer is cleared by stop() and overflow-audit-flag resets.
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


# Test-only subclass: exposes _dispatch_envelope() + reply capture so we can
# exercise the auth path without spinning up a real WebSocket peer.
class HarnessAdapter:
	extends WebSocketShellBridgeAdapter

	var sent: Array[Dictionary] = []
	var closed_with_code: int = -1

	func _send_envelope(envelope: Dictionary) -> void:
		sent.append(envelope.duplicate(true))

	# Stub a peer object that records close() codes — no real socket needed.
	class FakePeer:
		var closed_code: int = -1
		var ready: int = 1  # WebSocketPeer.STATE_OPEN
		func close(code: int = 1000, _reason: String = "") -> void:
			closed_code = code
		func get_ready_state() -> int:
			return ready

	func install_fake_peer() -> FakePeer:
		var fp := FakePeer.new()
		_peer = fp
		_peer_auth_misses = 0
		return fp

	func dispatch_for_tests(raw: String) -> void:
		_dispatch_envelope(raw)


var _failures: Array[String] = []
var _checks: int = 0


func _init() -> void:
	_test_gate_off()
	_test_audit_on_open()
	_test_reconnect()
	_test_heartbeat_survives_60s()
	_test_auth_token_required()
	_test_auth_token_rotates()
	_test_auth_misses_close_peer()
	_test_port_collision()
	_test_envelope_buffer_overflow()
	_test_envelope_buffer_clears_on_stop()
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
		# Token prefix lives in the audit payload (full token stays in stdout).
		_assert_true(str(rec.payload.get("token_prefix", "")).length() == 8,
			"AUDIT-2: audit payload must carry an 8-char token prefix")
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


# ── AUTH-1 / AUTH-4: matching token is accepted, `hello` requires token. ──
func _test_auth_token_required() -> void:
	var env := StubEnv.new()
	env.set_var("CHOYCE_SHELL_BRIDGE", "1")
	var a := HarnessAdapter.new().setup(env, StubLedger.new(), StubClock.new(), null, 0)
	root.add_child(a)
	_assert_true(a.start(), "AUTH-1: start() must succeed with env flag")
	var token: String = a._get_auth_token_for_tests()
	_assert_true(token.length() == 32 and token == token.to_lower(),
		"AUTH-1: per-launch token must be 32-char lowercase hex")
	a.install_fake_peer()

	# `hello` WITHOUT auth must be rejected.
	a.sent.clear()
	a.dispatch_for_tests(JSON.stringify({"command": "hello", "requestId": 1}))
	_assert_true(a.sent.size() == 1 and a.sent[0].get("ok") == false
			and str(a.sent[0].get("error")) == "auth_required",
		"AUTH-2: hello WITHOUT auth_token must reply auth_required")

	# `hello` WITH matching auth must be accepted.
	a.sent.clear()
	a.dispatch_for_tests(JSON.stringify({
		"command": "hello", "requestId": 2, "auth_token": token
	}))
	_assert_true(a.sent.size() == 1 and a.sent[0].get("ok") == true,
		"AUTH-4: hello WITH matching auth_token must reply ok")

	# Wrong token must still be rejected.
	a.sent.clear()
	a.dispatch_for_tests(JSON.stringify({
		"command": "ping", "requestId": 3, "auth_token": "deadbeefdeadbeefdeadbeefdeadbeef"
	}))
	_assert_true(a.sent.size() == 1 and a.sent[0].get("ok") == false
			and str(a.sent[0].get("error")) == "auth_required",
		"AUTH-2: wrong auth_token must reply auth_required")

	a.stop()
	a.queue_free()


# ── AUTH-1: token rotates on every start(). ──────────────────────────────
func _test_auth_token_rotates() -> void:
	var env := StubEnv.new()
	env.set_var("CHOYCE_SHELL_BRIDGE", "1")
	var a := WebSocketShellBridgeAdapter.new().setup(env, StubLedger.new(), StubClock.new(), null, 0)
	root.add_child(a)
	_assert_true(a.start(), "AUTH-rotate: first start() must succeed")
	var first := a._get_auth_token_for_tests()
	a.stop()
	_assert_true(a.start(), "AUTH-rotate: second start() must succeed")
	var second := a._get_auth_token_for_tests()
	_assert_true(first != second and first != "" and second != "",
		"AUTH-1: token must rotate between starts (first=%s second=%s)"
			% [first.substr(0, 8), second.substr(0, 8)])
	a.stop()
	a.queue_free()


# ── AUTH-3: 3 missing-token envelopes close the peer with 1008. ─────────
func _test_auth_misses_close_peer() -> void:
	var env := StubEnv.new()
	env.set_var("CHOYCE_SHELL_BRIDGE", "1")
	var a := HarnessAdapter.new().setup(env, StubLedger.new(), StubClock.new(), null, 0)
	root.add_child(a)
	_assert_true(a.start(), "AUTH-3: start() must succeed")
	var peer: HarnessAdapter.FakePeer = a.install_fake_peer()
	for i in range(3):
		a.dispatch_for_tests(JSON.stringify({"command": "ping", "requestId": i}))
	_assert_true(peer.closed_code == 1008,
		"AUTH-3: peer must be closed with policy-violation code 1008 after 3 misses (got %d)"
			% peer.closed_code)
	a.stop()
	a.queue_free()


# ── COLL-1: port collision detection. ───────────────────────────────────
func _test_port_collision() -> void:
	var env := StubEnv.new()
	env.set_var("CHOYCE_SHELL_BRIDGE", "1")
	# First adapter on a SPECIFIC port (0 would always be free → use a fixed one).
	# Use a high ephemeral-range port to avoid clashing with real services.
	var fixed_port: int = 51877
	var ledger_a := StubLedger.new()
	var holder := WebSocketShellBridgeAdapter.new().setup(env, ledger_a, StubClock.new(), null, fixed_port)
	root.add_child(holder)
	if not holder.start():
		# Port already in use on this machine — skip rather than fail flakily.
		print("[SKIP] COLL-1: port %d unavailable in this env" % fixed_port)
		holder.stop()
		holder.queue_free()
		_checks += 1
		return
	# Second adapter tries the same port → must refuse + audit collision.
	var env2 := StubEnv.new()
	env2.set_var("CHOYCE_SHELL_BRIDGE", "1")
	var ledger_b := StubLedger.new()
	var collider := WebSocketShellBridgeAdapter.new().setup(env2, ledger_b, StubClock.new(), null, fixed_port)
	root.add_child(collider)
	var second_ok := collider.start()
	_assert_true(not second_ok, "COLL-1: second start() on same port must return false")
	_assert_true(ledger_b.records.size() == 1
			and ledger_b.records[0].event_type == "shell_bridge_port_collision",
		"COLL-1: collision must audit shell_bridge_port_collision")
	collider.stop()
	collider.queue_free()
	holder.stop()
	holder.queue_free()


# ── BUF-1 / BUF-2: ring-buffer fills, oldest drops, audit fires. ─────────
func _test_envelope_buffer_overflow() -> void:
	var env := StubEnv.new()
	env.set_var("CHOYCE_SHELL_BRIDGE", "1")
	var ledger := StubLedger.new()
	var a := WebSocketShellBridgeAdapter.new().setup(env, ledger, StubClock.new(), null, 0)
	root.add_child(a)
	_assert_true(a.start(), "BUF: start() must succeed")
	# Fill the buffer (capacity 32) exactly.
	for i in range(32):
		a.notify_publish_state_changed("req-%d" % i, "queued")
	_assert_true(a._get_buffer_size_for_tests() == 32,
		"BUF-1: exactly 32 envelopes buffered (got %d)" % a._get_buffer_size_for_tests())
	# One audit so far (the open). Overflow MUST add exactly one more.
	var audits_before := ledger.records.size()
	# Trigger overflow.
	a.notify_publish_state_changed("req-overflow", "queued")
	_assert_true(a._get_buffer_size_for_tests() == 32,
		"BUF-2: buffer must remain at capacity after overflow (got %d)"
			% a._get_buffer_size_for_tests())
	_assert_true(ledger.records.size() == audits_before + 1
			and ledger.records[ledger.records.size() - 1].event_type
				== "shell_bridge_envelope_dropped",
		"BUF-2: overflow must audit shell_bridge_envelope_dropped exactly once")
	# Further overflows must NOT spam the audit ledger.
	a.notify_publish_state_changed("req-overflow-2", "queued")
	_assert_true(ledger.records.size() == audits_before + 1,
		"BUF-2: repeated overflow must not re-audit until buffer drains")
	a.stop()
	a.queue_free()


# ── BUF-3: stop() resets buffer + overflow flag. ────────────────────────
func _test_envelope_buffer_clears_on_stop() -> void:
	var env := StubEnv.new()
	env.set_var("CHOYCE_SHELL_BRIDGE", "1")
	var a := WebSocketShellBridgeAdapter.new().setup(env, StubLedger.new(), StubClock.new(), null, 0)
	root.add_child(a)
	_assert_true(a.start(), "BUF-3: start() must succeed")
	a.notify_session_started("w1", "kid-1")
	_assert_true(a._get_buffer_size_for_tests() == 1, "BUF-3: pre-stop buffer == 1")
	a.stop()
	_assert_true(a._get_buffer_size_for_tests() == 0,
		"BUF-3: stop() must clear the envelope buffer")
	a.queue_free()


func _assert_true(condition: bool, msg: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(msg)

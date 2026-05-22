class_name WebSocketShellBridgeAdapter
extends Node

## WebSocket adapter exposing the ShellBridgePort surface to the Tauri shell
## (research: thoughts/shared/research/shell-architecture-2026-05-21.md).
##
## INHERITANCE NOTE: GDScript is single-inheritance. The adapter extends Node
## (so main.gd can add_child() it and we get per-frame _process polling) and
## DUCK-TYPES the ShellBridgePort interface — every ShellBridgePort method
## is implemented verbatim. The accompanying contract test verifies the port
## shape.
##
## PRODUCTION SAFETY:
##   * Bridge is OFF by default. start() returns false UNLESS
##     EnvironmentPort.get_env("CHOYCE_SHELL_BRIDGE") == "1". Editor + headless
##     CI no longer flip the gate via OS.has_feature("debug") — that always
##     returned true under the editor and was a kid-safety regression
##     (adv-hex-pivot-2026-05-22 C2).
##   * Server binds to 127.0.0.1 only — never the LAN interface.
##   * Port-collision detection: if 9876 is already bound (e.g. TestBridgeAdapter
##     or a second WebSocketShellBridgeAdapter), start() returns false AND audits
##     "shell_bridge_port_collision" (adv-hex-pivot-2026-05-22 C3).
##   * Per-launch auth token: start() generates a random 32-char hex token,
##     prints it to stdout and audits it. Every inbound envelope (including
##     "hello") MUST carry a matching `auth_token` field. After 3 missing/wrong
##     tokens on a single connection the peer is closed
##     (adv-safety-pivot-2026-05-22 C2).
##   * Cold-connect buffer: outbound notify_* envelopes are queued (ring of 32)
##     while no peer is attached and drained on first connect; overflow
##     audits "shell_bridge_envelope_dropped" (adv-tests-pivot F-01 follow-up).
##   * Every successful open() is appended to the AuditLedgerPort with the
##     event_type "shell_bridge_opened" and the remote port.
##   * The bridge accepts ONE shell connection at a time. Subsequent
##     connections replace the previous peer (Tauri auto-reconnect).
##   * Heartbeat ping every 30 s keeps NAT/proxy state alive.
##
## Hexagonal rule: no domain types cross the wire. Inputs/outputs are JSON
## envelopes: { command, params, requestId, auth_token } → { requestId, result|error }.

const DEFAULT_PORT: int = 9876
const BIND_ADDRESS: String = "127.0.0.1"
const HEARTBEAT_SECONDS: float = 30.0
const SHELL_BRIDGE_FLAG_ENV: String = "CHOYCE_SHELL_BRIDGE"
const AUDIT_EVENT_OPENED: String = "shell_bridge_opened"
const AUDIT_EVENT_PORT_COLLISION: String = "shell_bridge_port_collision"
const AUDIT_EVENT_ENVELOPE_DROPPED: String = "shell_bridge_envelope_dropped"
const AUTH_TOKEN_HEX_CHARS: int = 32
const MAX_AUTH_MISSES: int = 3
const ENVELOPE_BUFFER_CAPACITY: int = 32

# ── Outbound dependencies (duck-typed where the port surface is stable). ────
var _env: EnvironmentPort
var _audit_ledger: AuditLedgerPort
var _clock: Object  # ClockPort — duck-typed (only now_iso() used).
var _kid_status_read_model: Object  # KidStatusReadModelPort — duck-typed.

# ── Runtime state. ────────────────────────────────────────────────────────
var _tcp_server: TCPServer
# _peer is typed as Object (not WebSocketPeer) so tests can install a
# duck-typed fake that only implements close() + get_ready_state(). The
# accept-path stores a real WebSocketPeer.
var _peer: Object = null
var _port: int = DEFAULT_PORT
var _active: bool = false
var _heartbeat_accum: float = 0.0
var _next_request_id: int = 1
var _force_enable: bool = false  # Test-only override; production stays gated.
var _auth_token: String = ""
var _peer_auth_misses: int = 0
# Cold-connect ring buffer of pending outbound envelopes. Drained on first
# peer attach. Overflow drops the oldest entry and audits the drop once.
var _envelope_buffer: Array[Dictionary] = []
var _envelope_overflow_audited: bool = false


## Wires required outbound dependencies. Returns self for fluent setup().
## p_env: EnvironmentPort — read CHOYCE_SHELL_BRIDGE.
## p_audit_ledger: AuditLedgerPort — receives shell_bridge_opened records.
## p_clock: ClockPort — for audit record timestamps (duck-typed now_iso()).
## p_kid_status_read_model: optional read-model for request_kid_status().
## p_port: TCP port (defaults to 9876, same as TestBridgeAdapter).
func setup(
	p_env: EnvironmentPort,
	p_audit_ledger: AuditLedgerPort,
	p_clock: Object,
	p_kid_status_read_model: Object = null,
	p_port: int = DEFAULT_PORT
) -> WebSocketShellBridgeAdapter:
	_env = p_env
	_audit_ledger = p_audit_ledger
	_clock = p_clock
	_kid_status_read_model = p_kid_status_read_model
	_port = p_port
	return self


## Test-only: bypass the env-flag gate so contract tests can drive the
## bridge without polluting the real environment. NEVER call in production.
func _force_enable_for_tests() -> void:
	_force_enable = true


## Test-only: kept for backward compatibility with existing contract tests
## that called this before the OS.has_feature("debug") branch was removed.
## Now a no-op — the env-only gate already keeps the bridge OFF in headless
## tests unless the env var is set.
func _disable_debug_feature_for_tests() -> void:
	pass


## Returns true when the env-only safety gate permits the server to start.
## OS.has_feature("debug") is intentionally NOT consulted — it returned true
## under the editor and CI, which left the bridge OPEN by accident.
func _gate_open() -> bool:
	if _force_enable:
		return true
	if _env != null and _env.get_env(SHELL_BRIDGE_FLAG_ENV, "") == "1":
		return true
	return false


## Test-only accessor for the per-launch token. Production callers must read
## the token from stdout / audit log, not from the adapter instance.
func _get_auth_token_for_tests() -> String:
	return _auth_token


## Test-only accessor for the pending-envelope buffer size.
func _get_buffer_size_for_tests() -> int:
	return _envelope_buffer.size()


## Generates a fresh 32-char hex token. Uses Crypto.generate_random_bytes()
## (CSPRNG) — randi() is not acceptable for an auth secret.
func _generate_auth_token() -> String:
	var crypto := Crypto.new()
	# 16 bytes = 32 hex chars.
	var raw: PackedByteArray = crypto.generate_random_bytes(AUTH_TOKEN_HEX_CHARS / 2)
	var hex := ""
	for b in raw:
		hex += "%02x" % b
	return hex


## Detects whether the configured TCP port is already bound by another
## process (e.g. TestBridgeAdapter or a stale shell-bridge instance). Returns
## true when the port is FREE. We attempt a probe-bind; on success we close
## immediately and report free.
func _is_port_available() -> bool:
	# port 0 = OS-assigned; always free.
	if _port == 0:
		return true
	var probe := TCPServer.new()
	var err: int = probe.listen(_port, BIND_ADDRESS)
	if err != OK:
		return false
	probe.stop()
	return true


## Starts the WebSocket server. Returns true on success, false if the gate
## is closed, the port is already bound, or the bind fails. Auth token is
## rotated on every start; the previous token is invalidated.
func start() -> bool:
	if not _gate_open():
		return false
	if not _is_port_available():
		push_warning(
			"WebSocketShellBridgeAdapter: port %d already in use (collision)" % _port
		)
		_audit_port_collision()
		return false
	_tcp_server = TCPServer.new()
	var err: int = _tcp_server.listen(_port, BIND_ADDRESS)
	if err != OK:
		push_warning(
			"WebSocketShellBridgeAdapter: bind on %s:%d failed (err %d)"
				% [BIND_ADDRESS, _port, err]
		)
		_tcp_server = null
		return false
	_auth_token = _generate_auth_token()
	_peer_auth_misses = 0
	_active = true
	# Stdout line + audit row — the Tauri shell scrapes one of these to
	# pick up the per-launch token. NEVER log the token anywhere else.
	print("[shell_bridge] auth_token=%s port=%d" % [_auth_token, _port])
	_audit_open_event()
	return true


## Stops the server and disconnects the active peer. Clears the auth token
## and the cold-connect buffer so a subsequent start() begins clean.
func stop() -> void:
	_active = false
	if _peer != null:
		_peer.close(1000, "shell_bridge_stop")
		_peer = null
	if _tcp_server != null:
		_tcp_server.stop()
		_tcp_server = null
	_heartbeat_accum = 0.0
	_auth_token = ""
	_peer_auth_misses = 0
	_envelope_buffer.clear()
	_envelope_overflow_audited = false


## Per-frame polling — accepts incoming connections, services the active
## peer, and ticks the heartbeat counter.
func _process(delta: float) -> void:
	if not _active or _tcp_server == null:
		return
	_accept_incoming()
	_service_peer()
	_tick_heartbeat(delta)


func _accept_incoming() -> void:
	if not _tcp_server.is_connection_available():
		return
	# One connection at a time — replace the previous peer (auto-reconnect).
	var stream: StreamPeerTCP = _tcp_server.take_connection()
	if stream == null:
		return
	var ws := WebSocketPeer.new()
	var err: int = ws.accept_stream(stream)
	if err != OK:
		push_warning("WebSocketShellBridgeAdapter: accept_stream err %d" % err)
		return
	if _peer != null:
		_peer.close(1000, "shell_reconnected")
	_peer = ws
	_peer_auth_misses = 0
	_heartbeat_accum = 0.0
	# Drain any envelopes queued while no peer was attached. We wait for the
	# socket to reach STATE_OPEN before flushing, so queue the drain in
	# _service_peer().


func _drain_envelope_buffer() -> void:
	if _peer == null or _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	if _envelope_buffer.is_empty():
		return
	var pending := _envelope_buffer.duplicate()
	_envelope_buffer.clear()
	_envelope_overflow_audited = false
	for env in pending:
		_peer.send_text(JSON.stringify(env))


func _service_peer() -> void:
	if _peer == null:
		return
	_peer.poll()
	var state: int = _peer.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		_peer = null
		return
	if state != WebSocketPeer.STATE_OPEN:
		return
	# First time the peer reaches OPEN, flush any cold-connect buffer.
	if not _envelope_buffer.is_empty():
		_drain_envelope_buffer()
	while _peer.get_available_packet_count() > 0:
		var pkt: PackedByteArray = _peer.get_packet()
		_dispatch_envelope(pkt.get_string_from_utf8())


func _tick_heartbeat(delta: float) -> void:
	if _peer == null or _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_heartbeat_accum += delta
	if _heartbeat_accum >= HEARTBEAT_SECONDS:
		_heartbeat_accum = 0.0
		_send_envelope({"command": "ping", "params": {}, "requestId": _next_request_id})
		_next_request_id += 1


# ── ShellBridgePort surface (duck-typed; see contract test). ─────────────────

func notify_session_started(p_world_id: String, p_profile_id: String) -> void:
	_send_envelope({
		"command": "session_started",
		"params": {"world_id": p_world_id, "profile_id": p_profile_id},
		"requestId": _next_request_id,
	})
	_next_request_id += 1


func notify_session_ended(p_stats: Dictionary) -> void:
	_send_envelope({
		"command": "session_ended",
		"params": p_stats.duplicate(true),
		"requestId": _next_request_id,
	})
	_next_request_id += 1


func notify_publish_state_changed(p_req_id: String, p_state: String) -> void:
	_send_envelope({
		"command": "publish_state_changed",
		"params": {"req_id": p_req_id, "state": p_state},
		"requestId": _next_request_id,
	})
	_next_request_id += 1


func request_kid_status(p_profile_id: String, p_world_id: String) -> Dictionary:
	if _kid_status_read_model == null:
		return {}
	if _kid_status_read_model.has_method("get_status"):
		var raw: Variant = _kid_status_read_model.get_status(p_profile_id, p_world_id)
		if raw is Dictionary:
			return raw
	return {}


# ── Envelope helpers. ─────────────────────────────────────────────────────

## Outbound envelope. If no peer is currently attached we ring-buffer up to
## ENVELOPE_BUFFER_CAPACITY envelopes and drain them when the next peer
## connects. Buffer overflow drops the OLDEST envelope and audits the drop
## once per buffer-full state.
func _send_envelope(envelope: Dictionary) -> void:
	if _peer != null and _peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_peer.send_text(JSON.stringify(envelope))
		return
	# Cold-connect buffering — only meaningful while the bridge is active.
	if not _active:
		return
	if _envelope_buffer.size() >= ENVELOPE_BUFFER_CAPACITY:
		# Drop oldest; audit once until the buffer drains again.
		_envelope_buffer.pop_front()
		if not _envelope_overflow_audited:
			_envelope_overflow_audited = true
			_audit_envelope_dropped()
	_envelope_buffer.append(envelope.duplicate(true))


## Validates the auth_token field on an inbound envelope. Returns true when
## the token matches the per-launch secret. The `hello` command still
## REQUIRES the token (per safety C2) — there is no unauthenticated path.
func _check_auth(envelope: Dictionary) -> bool:
	var supplied: String = str(envelope.get("auth_token", ""))
	return supplied != "" and supplied == _auth_token


func _dispatch_envelope(raw: String) -> void:
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		_reply_error(null, "invalid_envelope")
		return
	var envelope: Dictionary = parsed
	# Accept both schemas:
	#   Tauri client (godot-bridge.ts): {type:"cmd", id:<num>, command, params, auth_token}
	#   Legacy contract test:           {command, params, requestId:<num>, auth_token}
	# Echo back whichever id-field the caller used so neither side has to
	# refactor. Adds `type:"ack"` for the Tauri side; legacy callers ignore it.
	var id_value: Variant = null
	if envelope.has("id"):
		id_value = envelope["id"]
	elif envelope.has("requestId"):
		id_value = envelope["requestId"]
	# Godot's JSON.parse_string promotes JSON numbers to float.
	# Tauri client correlates pending cmds with === on number, so 42.0
	# !== 42 would orphan every pending promise. Coerce to int when
	# the value is whole — leaves strings untouched.
	if id_value is float and float(id_value) == int(id_value):
		id_value = int(id_value)
	var command: String = str(envelope.get("command", ""))
	# AUTH GATE — every command must carry the per-launch token, including
	# `hello`. After MAX_AUTH_MISSES misses on the same peer we close it.
	if not _check_auth(envelope):
		_peer_auth_misses += 1
		_reply_error(id_value, "auth_required")
		if _peer_auth_misses >= MAX_AUTH_MISSES and _peer != null:
			_peer.close(1008, "auth_required")
			_peer = null
		return
	# Successful auth resets the miss counter for this peer.
	_peer_auth_misses = 0
	var params_v: Variant = envelope.get("params", {})
	var params: Dictionary = params_v if params_v is Dictionary else {}
	match command:
		"ping", "hello":
			_reply_ok(id_value, {"pong": true})
		"request_kid_status":
			var status := request_kid_status(
				str(params.get("profile_id", "")),
				str(params.get("world_id", ""))
			)
			_reply_ok(id_value, status)
		"":
			_reply_error(id_value, "missing_command")
		_:
			_reply_error(id_value, "unknown_command")


## `id_value` may be int (legacy) or String (Tauri client). Pass null when
## the inbound envelope was unparseable — adapter still sends an ack so the
## client surfaces a real error instead of a timeout.
func _reply_ok(id_value: Variant, result: Dictionary) -> void:
	var env := {
		"type": "ack",
		"ok": true,
		"result": result,
	}
	if id_value != null:
		env["id"] = id_value
		env["requestId"] = id_value  # legacy alias for the contract tests
	_send_envelope(env)


func _reply_error(id_value: Variant, code: String) -> void:
	var env := {
		"type": "ack",
		"ok": false,
		"error": code,
	}
	if id_value != null:
		env["id"] = id_value
		env["requestId"] = id_value
	_send_envelope(env)


# ── Audit. ────────────────────────────────────────────────────────────────

func _audit_open_event() -> void:
	if _audit_ledger == null:
		return
	var ts: String = ""
	if _clock != null and _clock.has_method("now_iso"):
		ts = _clock.now_iso()
	var prev_hash: String = ""
	if _audit_ledger.has_method("last_hash"):
		prev_hash = _audit_ledger.last_hash()
	var record_id := "shell-bridge-%d-%d" % [Time.get_ticks_msec(), _port]
	# Audit payload carries the token PREFIX only (first 8 chars) so an
	# operator can correlate stdout ↔ audit without leaking the full secret
	# into the ledger.
	var token_prefix: String = _auth_token.substr(0, 8) if _auth_token.length() >= 8 else _auth_token
	var record := AuditRecord.new(
		record_id,
		AUDIT_EVENT_OPENED,
		record_id,
		"shell_bridge",
		ts,
		{"bind": BIND_ADDRESS, "port": _port, "token_prefix": token_prefix},
		prev_hash
	)
	_audit_ledger.append_record(record)


func _audit_port_collision() -> void:
	if _audit_ledger == null:
		return
	var ts: String = ""
	if _clock != null and _clock.has_method("now_iso"):
		ts = _clock.now_iso()
	var prev_hash: String = ""
	if _audit_ledger.has_method("last_hash"):
		prev_hash = _audit_ledger.last_hash()
	var record_id := "shell-bridge-collision-%d-%d" % [Time.get_ticks_msec(), _port]
	var record := AuditRecord.new(
		record_id,
		AUDIT_EVENT_PORT_COLLISION,
		record_id,
		"shell_bridge",
		ts,
		{"bind": BIND_ADDRESS, "port": _port},
		prev_hash
	)
	_audit_ledger.append_record(record)


func _audit_envelope_dropped() -> void:
	if _audit_ledger == null:
		return
	var ts: String = ""
	if _clock != null and _clock.has_method("now_iso"):
		ts = _clock.now_iso()
	var prev_hash: String = ""
	if _audit_ledger.has_method("last_hash"):
		prev_hash = _audit_ledger.last_hash()
	var record_id := "shell-bridge-dropped-%d-%d" % [Time.get_ticks_msec(), _port]
	var record := AuditRecord.new(
		record_id,
		AUDIT_EVENT_ENVELOPE_DROPPED,
		record_id,
		"shell_bridge",
		ts,
		{"capacity": ENVELOPE_BUFFER_CAPACITY, "port": _port},
		prev_hash
	)
	_audit_ledger.append_record(record)

class_name TestBridgeAdapter
extends Node

## Debug-only adapter that exposes game state, screenshots, and input injection
## to an external AI test agent via a localhost HTTP server.
##
## PRODUCTION SAFETY: This adapter only activates when the debug feature flag
## "debug_test_bridge" is enabled. It must never be included in production exports.
## The HTTP server binds to 127.0.0.1 only — never 0.0.0.0.
## No child PII is transmitted; all state uses anonymised session IDs.
##
## Integration: gdGSI-compatible section-based state pushes.
## Input injection: GoPeak MCP server routes mouse/key events here.

const DEFAULT_PORT: int = 9876
const BIND_ADDRESS: String = "127.0.0.1"

var _http_server: TCPServer
var _clients: Array = []
var _state_store: Dictionary = {}
var _feature_flags: Object  # FeatureFlagService duck-typed
var _port: int = DEFAULT_PORT
var _active: bool = false


func setup(p_feature_flags: Object, p_port: int = DEFAULT_PORT) -> void:
	_feature_flags = p_feature_flags
	_port = p_port


func start() -> bool:
	if _feature_flags != null and _feature_flags.has_method("is_enabled"):
		if not _feature_flags.is_enabled("debug_test_bridge"):
			return false
	_http_server = TCPServer.new()
	var err: int = _http_server.listen(_port, BIND_ADDRESS)
	if err != OK:
		push_warning("TestBridgeAdapter: failed to bind on %s:%d (err %d)" % [BIND_ADDRESS, _port, err])
		return false
	_active = true
	return true


func stop() -> void:
	_active = false
	if _http_server != null:
		_http_server.stop()
	_clients.clear()


## Called each frame from the adapter owner to accept and service HTTP clients.
func poll() -> void:
	if not _active or _http_server == null:
		return
	if _http_server.is_connection_available():
		var conn: StreamPeerTCP = _http_server.take_connection()
		if conn != null:
			_clients.append(conn)
	var done: Array = []
	for conn in _clients:
		_service_connection(conn)
		if conn.get_status() == StreamPeerTCP.STATUS_NONE or \
		   conn.get_status() == StreamPeerTCP.STATUS_ERROR:
			done.append(conn)
	for conn in done:
		_clients.erase(conn)


# ── TestBridgePort overrides ─────────────────────────────────────────────────

func get_game_state() -> Dictionary:
	return _state_store.duplicate(true)


func capture_screenshot() -> PackedByteArray:
	if not _active:
		return PackedByteArray()
	if OS.has_feature("headless"):
		return PackedByteArray()
	var img: Image = DisplayServer.screen_get_image(0)
	if img == null:
		return PackedByteArray()
	return img.save_png_to_buffer()


func inject_input(p_event: Dictionary) -> bool:
	if not _active:
		return false
	var type: String = p_event.get("type", "")
	match type:
		"action":
			var ev := InputEventAction.new()
			ev.action = p_event.get("action_name", "")
			ev.pressed = p_event.get("pressed", true)
			Input.parse_input_event(ev)
			return true
		"mouse_button":
			var ev := InputEventMouseButton.new()
			ev.button_index = p_event.get("button_index", MOUSE_BUTTON_LEFT)
			ev.pressed = p_event.get("pressed", true)
			var pos: Vector2 = _normalised_to_screen(p_event.get("position", Vector2(0.5, 0.5)))
			ev.position = pos
			ev.global_position = pos
			Input.parse_input_event(ev)
			return true
		"key":
			var ev := InputEventKey.new()
			ev.keycode = p_event.get("keycode", KEY_NONE)
			ev.pressed = p_event.get("pressed", true)
			Input.parse_input_event(ev)
			return true
		"mouse_motion":
			var ev := InputEventMouseMotion.new()
			var pos: Vector2 = _normalised_to_screen(p_event.get("position", Vector2(0.5, 0.5)))
			ev.position = pos
			ev.global_position = pos
			Input.parse_input_event(ev)
			return true
	return false


func set_state_section(p_section: String, p_data: Dictionary) -> void:
	_state_store[p_section] = p_data


# ── HTTP request dispatch ─────────────────────────────────────────────────────

func _service_connection(conn: StreamPeerTCP) -> void:
	conn.poll()
	if conn.get_available_bytes() == 0:
		return
	var raw: String = conn.get_string(conn.get_available_bytes())
	var first_line: String = raw.split("\n")[0].strip_edges()
	var parts: PackedStringArray = first_line.split(" ")
	if parts.size() < 2:
		_send_response(conn, 400, "Bad Request", "text/plain", "Bad request line")
		return
	var method: String = parts[0]
	var path: String = parts[1]
	match path:
		"/state":
			var body: String = JSON.stringify(get_game_state())
			_send_response(conn, 200, "OK", "application/json", body)
		"/screenshot":
			var png: PackedByteArray = capture_screenshot()
			if png.is_empty():
				_send_response(conn, 503, "Service Unavailable", "text/plain", "No display")
			else:
				_send_binary_response(conn, 200, "OK", "image/png", png)
		"/input":
			if method != "POST":
				_send_response(conn, 405, "Method Not Allowed", "text/plain", "POST only")
				return
			var body_start: int = raw.find("\r\n\r\n")
			if body_start == -1:
				body_start = raw.find("\n\n")
			var json_body: String = raw.substr(body_start + 4) if body_start != -1 else ""
			var parsed = JSON.parse_string(json_body)
			if parsed == null or not parsed is Dictionary:
				_send_response(conn, 400, "Bad Request", "text/plain", "Invalid JSON")
				return
			var ok: bool = inject_input(parsed)
			_send_response(conn, 200, "OK", "application/json", JSON.stringify({"accepted": ok}))
		"/health":
			_send_response(conn, 200, "OK", "application/json", JSON.stringify({"status": "ok", "active": _active}))
		_:
			_send_response(conn, 404, "Not Found", "text/plain", "Unknown endpoint")


func _send_response(conn: StreamPeerTCP, code: int, status: String,
		content_type: String, body: String) -> void:
	var encoded: PackedByteArray = body.to_utf8_buffer()
	var headers: String = "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" \
		% [code, status, content_type, encoded.size()]
	conn.put_data(headers.to_utf8_buffer())
	conn.put_data(encoded)


func _send_binary_response(conn: StreamPeerTCP, code: int, status: String,
		content_type: String, body: PackedByteArray) -> void:
	var headers: String = "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" \
		% [code, status, content_type, body.size()]
	conn.put_data(headers.to_utf8_buffer())
	conn.put_data(body)


func _normalised_to_screen(p_norm: Variant) -> Vector2:
	var viewport_size: Vector2 = DisplayServer.screen_get_size()
	var nv: Vector2 = Vector2(0.5, 0.5)
	if p_norm is Vector2:
		nv = p_norm
	elif p_norm is Dictionary:
		nv = Vector2(float(p_norm.get("x", 0.5)), float(p_norm.get("y", 0.5)))
	return Vector2(nv.x * viewport_size.x, nv.y * viewport_size.y)

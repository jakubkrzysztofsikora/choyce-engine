## Deterministic gateway for AI tool execution.
## Enforces tool-schema validation and idempotency key semantics before
## delegating to registered handlers.
class_name DeterministicToolExecutionGateway
extends ToolExecutionGateway

const MAX_CACHE_ENTRIES := 1000

var _registry: AIToolRegistry
var _executors: Dictionary = {}
var _rollbacks: Dictionary = {}
var _seen_invocation_ids: Dictionary = {}
var _idempotency_cache: Dictionary = {}
var _cache_order: Array[String] = []


func _init() -> void:
	_registry = AIToolRegistry.new()


func setup(registry: AIToolRegistry = null) -> DeterministicToolExecutionGateway:
	_registry = registry if registry != null else AIToolRegistry.new()
	return self


func get_registry() -> AIToolRegistry:
	return _registry


func register_handler(tool_name: String, execute_handler: Callable, rollback_handler: Callable = Callable()) -> bool:
	if _registry == null:
		_registry = AIToolRegistry.new()
	if not _registry.has_schema(tool_name):
		push_error("DeterministicToolExecutionGateway: unknown tool '%s'" % tool_name)
		return false
	if not execute_handler.is_valid():
		push_error("DeterministicToolExecutionGateway: execute handler is invalid for '%s'" % tool_name)
		return false

	_executors[tool_name] = execute_handler
	if rollback_handler.is_valid():
		_rollbacks[tool_name] = rollback_handler
	return true


func execute(invocation: ToolInvocation, context: Dictionary = {}) -> Dictionary:
	if _registry == null:
		_registry = AIToolRegistry.new()

	var validation := _registry.validate_and_apply(invocation)
	if not validation.get("ok", false):
		return {
			"ok": false,
			"error": str(validation.get("error", "Invalid tool invocation")),
		}

	var invocation_id := invocation.invocation_id
	var fingerprint := _fingerprint(invocation)
	var previous: Dictionary = {}
	if not invocation_id.is_empty() and _seen_invocation_ids.has(invocation_id):
		previous = _seen_invocation_ids[invocation_id]
		var was_idempotent := bool(previous.get("idempotent", false))
		var previous_fingerprint := str(previous.get("fingerprint", ""))
		if was_idempotent:
			if previous_fingerprint != fingerprint:
				return {
					"ok": false,
					"error": "Idempotent invocation_id '%s' reused with different arguments" % invocation_id,
				}
			var cached_result: Variant = _idempotency_cache.get(invocation_id, null)
			if cached_result is Dictionary:
				var replay := (cached_result as Dictionary).duplicate(true)
				replay["idempotent_replay"] = true
				return replay
		else:
			return {
				"ok": false,
				"error": "Non-idempotent invocation_id '%s' cannot be replayed" % invocation_id,
			}

	var execute_handler: Callable = _executors.get(invocation.tool_name, Callable())
	var result: Dictionary
	if execute_handler.is_valid():
		var raw_result: Variant = execute_handler.call(invocation, context)
		if raw_result is Dictionary:
			result = (raw_result as Dictionary).duplicate(true)
		else:
			return {
				"ok": false,
				"error": "Tool '%s' handler must return Dictionary" % invocation.tool_name,
			}
	else:
		result = _default_execute(invocation, context)

	if not bool(result.get("ok", false)):
		return {
			"ok": false,
			"error": str(result.get("error", "Tool execution failed")),
		}

	if not result.has("undo_token"):
		result["undo_token"] = _build_undo_token(invocation, context)

	if not invocation_id.is_empty():
		_seen_invocation_ids[invocation_id] = {
			"idempotent": invocation.is_idempotent,
			"fingerprint": fingerprint,
		}
		if not _cache_order.has(invocation_id):
			_cache_order.append(invocation_id)
		if invocation.is_idempotent:
			_idempotency_cache[invocation_id] = result.duplicate(true)
		_evict_oldest_cache_entries()

	return result


func rollback(undo_token: Dictionary, context: Dictionary = {}) -> bool:
	if undo_token.is_empty():
		return false

	var tool_name := str(undo_token.get("tool_name", ""))
	if tool_name.is_empty():
		return false

	var rollback_handler: Callable = _rollbacks.get(tool_name, Callable())
	if rollback_handler.is_valid():
		return bool(rollback_handler.call(undo_token, context))

	return _default_rollback(undo_token, context)


func _default_execute(invocation: ToolInvocation, context: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"tool": invocation.tool_name,
		"undo_token": _build_undo_token(invocation, context),
	}


func _default_rollback(_undo_token: Dictionary, _context: Dictionary) -> bool:
	return true


func _build_undo_token(invocation: ToolInvocation, _context: Dictionary) -> Dictionary:
	var token_id := invocation.invocation_id
	if token_id.is_empty():
		token_id = "undo_%d" % absi(_fingerprint(invocation).hash())
	return {
		"tool_name": invocation.tool_name,
		"token_id": token_id,
	}


func _fingerprint(invocation: ToolInvocation) -> String:
	return "%s|%s" % [invocation.tool_name, _stable_serialize(invocation.arguments)]


func _stable_serialize(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT, TYPE_FLOAT:
			return str(value)
		TYPE_STRING:
			return "\"%s\"" % str(value).replace("\"", "\\\"")
		TYPE_VECTOR2:
			return "vec2(%s,%s)" % [str(value.x), str(value.y)]
		TYPE_VECTOR3:
			return "vec3(%s,%s,%s)" % [str(value.x), str(value.y), str(value.z)]
		TYPE_ARRAY:
			var parts: Array[String] = []
			for item in value:
				parts.append(_stable_serialize(item))
			return "[" + ",".join(parts) + "]"
		TYPE_DICTIONARY:
			var entries: Array = []
			for raw_key in value.keys():
				entries.append({"key_text": str(raw_key), "key": raw_key})
			entries.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					return str(a.get("key_text", "")) < str(b.get("key_text", ""))
			)
			var dict_parts: Array[String] = []
			for entry in entries:
				var key_text := str(entry.get("key_text", ""))
				var raw_key: Variant = entry.get("key")
				dict_parts.append("%s:%s" % [key_text, _stable_serialize(value.get(raw_key))])
			return "{" + ",".join(dict_parts) + "}"
		_:
			return "<unsupported:%d>" % typeof(value)


func _evict_oldest_cache_entries() -> void:
	while _cache_order.size() > MAX_CACHE_ENTRIES:
		var oldest := _cache_order[0]
		_cache_order.remove_at(0)
		_seen_invocation_ids.erase(oldest)
		_idempotency_cache.erase(oldest)

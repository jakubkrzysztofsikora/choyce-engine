## Registry for deterministic AI tool contracts.
## Stores per-tool schemas for argument validation, idempotency policy,
## and parent-approval requirements used by orchestration and execution.
class_name AIToolRegistry
extends RefCounted

var _schemas: Dictionary = {}


func _init(register_defaults: bool = true) -> void:
	_schemas = {}
	if register_defaults:
		_register_default_schemas()


func register_schema(tool_name: String, schema: Dictionary) -> bool:
	if tool_name.is_empty():
		push_error("AIToolRegistry.register_schema(): tool_name is required")
		return false

	var normalized := {
		"category": str(schema.get("category", "custom")),
		"argument_types": _normalize_argument_types(schema.get("argument_types", {})),
		"required_arguments": _normalize_string_array(schema.get("required_arguments", [])),
		"allow_unknown_arguments": bool(schema.get("allow_unknown_arguments", false)),
		"idempotent": bool(schema.get("idempotent", false)),
		"requires_parent_approval": bool(schema.get("requires_parent_approval", false)),
	}
	_schemas[tool_name] = normalized
	return true


func has_schema(tool_name: String) -> bool:
	return _schemas.has(tool_name)


func get_schema(tool_name: String) -> Dictionary:
	if not _schemas.has(tool_name):
		return {}
	return _schemas[tool_name].duplicate(true)


func list_tool_names() -> Array[String]:
	var names: Array[String] = []
	for name in _schemas.keys():
		names.append(str(name))
	names.sort()
	return names


func list_schemas() -> Dictionary:
	return _schemas.duplicate(true)


func validate_invocation(invocation: ToolInvocation) -> Dictionary:
	if invocation == null:
		return {"ok": false, "error": "Tool invocation is required"}
	if invocation.tool_name.is_empty():
		return {"ok": false, "error": "Tool name is required"}
	if not _schemas.has(invocation.tool_name):
		return {
			"ok": false,
			"error": "Tool '%s' is not registered" % invocation.tool_name,
		}

	var schema: Dictionary = _schemas[invocation.tool_name]
	var required_args: Array = schema.get("required_arguments", [])
	for required_arg in required_args:
		var arg_name := str(required_arg)
		if not invocation.arguments.has(arg_name):
			return {
				"ok": false,
				"error": "Tool '%s' is missing required argument '%s'" % [invocation.tool_name, arg_name],
			}

	var arg_types: Dictionary = schema.get("argument_types", {})
	var allow_unknown := bool(schema.get("allow_unknown_arguments", false))
	for raw_key in invocation.arguments.keys():
		var key := str(raw_key)
		var value: Variant = invocation.arguments[raw_key]
		if not _is_deterministic_value(value):
			return {
				"ok": false,
				"error": "Tool '%s' has non-deterministic argument '%s'" % [invocation.tool_name, key],
			}
		if not allow_unknown and not arg_types.has(key):
			return {
				"ok": false,
				"error": "Tool '%s' has undeclared argument '%s'" % [invocation.tool_name, key],
			}
		if arg_types.has(key):
			var expected_type := str(arg_types.get(key, "any"))
			if not _matches_expected_type(value, expected_type):
				return {
					"ok": false,
					"error": "Tool '%s' argument '%s' must be %s" % [invocation.tool_name, key, expected_type],
				}

	if bool(schema.get("idempotent", false)) and invocation.invocation_id.is_empty():
		return {
			"ok": false,
			"error": "Tool '%s' requires invocation_id for idempotency" % invocation.tool_name,
		}

	if invocation.tool_name == "safety_check":
		var text_value := str(invocation.arguments.get("text", "")).strip_edges()
		var image_ref := str(invocation.arguments.get("image_ref", "")).strip_edges()
		if text_value.is_empty() and image_ref.is_empty():
			return {
				"ok": false,
				"error": "Tool 'safety_check' requires at least one of: text, image_ref",
			}

	return {"ok": true, "schema": schema.duplicate(true)}


func validate_and_apply(invocation: ToolInvocation) -> Dictionary:
	var validation := validate_invocation(invocation)
	if not validation.get("ok", false):
		return validation

	var schema: Dictionary = validation.get("schema", {})
	invocation.is_idempotent = bool(schema.get("idempotent", false))
	invocation.requires_approval = bool(schema.get("requires_parent_approval", false))
	return validation


func _register_default_schemas() -> void:
	register_schema(
		"scene_edit",
		{
			"category": "world",
			"argument_types": {
				"world_id": "string",
				"action": "string",
				"target_node_id": "string",
				"new_state": "dictionary",
				"op": "any",
			},
			"required_arguments": [],
			"allow_unknown_arguments": true,
			"idempotent": true,
			"requires_parent_approval": false,
		}
	)
	register_schema(
		"logic_edit",
		{
			"category": "logic",
			"argument_types": {
				"world_id": "string",
				"rule_id": "string",
				"source_blocks": "array",
				"patch": "dictionary",
			},
			"required_arguments": [],
			"allow_unknown_arguments": true,
			"idempotent": true,
			"requires_parent_approval": true,
		}
	)
	register_schema(
		"asset_import",
		{
			"category": "asset",
			"argument_types": {
				"world_id": "string",
				"asset_ref": "string",
				"asset_kind": "string",
				"asset_bytes_base64": "string",
			},
			"required_arguments": [],
			"allow_unknown_arguments": true,
			"idempotent": false,
			"requires_parent_approval": true,
		}
	)
	register_schema(
		"visual_generate",
		{
			"category": "asset",
			"argument_types": {
				"project_id": "string",
				"world_id": "string",
				"prompt": "string",
				"style_preset": "string",
				"target_slot": "string",
				"preview_only": "bool",
			},
			"required_arguments": ["project_id", "world_id", "prompt", "style_preset"],
			"allow_unknown_arguments": false,
			"idempotent": false,
			"requires_parent_approval": false,
		}
	)
	register_schema(
		"playtest",
		{
			"category": "playtest",
			"argument_types": {
				"world_id": "string",
				"players": "array",
			},
			"required_arguments": [],
			"allow_unknown_arguments": true,
			"idempotent": false,
			"requires_parent_approval": false,
		}
	)
	register_schema(
		"safety_check",
		{
			"category": "safety",
			"argument_types": {
				"text": "string",
				"image_ref": "string",
				"mode": "string",
			},
			"required_arguments": [],
			"allow_unknown_arguments": false,
			"idempotent": true,
			"requires_parent_approval": false,
		}
	)

	# Existing orchestration tools remain declared for compatibility.
	register_schema(
		"paint",
		{
			"category": "world",
			"argument_types": {
				"color": "string",
				"target_node_id": "string",
				"op": "any",
			},
			"required_arguments": [],
			"allow_unknown_arguments": true,
			"idempotent": true,
			"requires_parent_approval": false,
		}
	)
	register_schema(
		"duplicate",
		{
			"category": "world",
			"argument_types": {
				"target_node_id": "string",
				"new_id": "string",
			},
			"required_arguments": [],
			"allow_unknown_arguments": true,
			"idempotent": false,
			"requires_parent_approval": false,
		}
	)
	register_schema(
		"script_edit",
		{
			"category": "logic",
			"argument_types": {
				"code": "string",
				"path": "string",
			},
			"required_arguments": [],
			"allow_unknown_arguments": true,
			"idempotent": false,
			"requires_parent_approval": true,
		}
	)


func _normalize_argument_types(raw_types: Variant) -> Dictionary:
	if not (raw_types is Dictionary):
		return {}
	var normalized := {}
	for raw_key in raw_types.keys():
		normalized[str(raw_key)] = str(raw_types[raw_key]).to_lower()
	return normalized


func _normalize_string_array(raw_values: Variant) -> Array[String]:
	var normalized: Array[String] = []
	if not (raw_values is Array):
		return normalized
	for raw_value in raw_values:
		normalized.append(str(raw_value))
	return normalized


func _matches_expected_type(value: Variant, expected_type: String) -> bool:
	match expected_type:
		"any":
			return _is_deterministic_value(value)
		"string":
			return typeof(value) == TYPE_STRING
		"int":
			return typeof(value) == TYPE_INT
		"float":
			return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT
		"number":
			return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT
		"bool":
			return typeof(value) == TYPE_BOOL
		"dictionary":
			return value is Dictionary
		"array":
			return value is Array
		"vector2":
			return value is Vector2
		"vector3":
			return value is Vector3
		_:
			return false


func _is_deterministic_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_VECTOR2, TYPE_VECTOR3:
			return true
		TYPE_ARRAY:
			for item in value:
				if not _is_deterministic_value(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value.keys():
				var key_type := typeof(key)
				if key_type not in [TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
					return false
				if not _is_deterministic_value(value[key]):
					return false
			return true
		_:
			# Callable, Object, RID, and engine handles are non-deterministic.
			return false

class_name AIToolRegistryContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()

	var registry := AIToolRegistry.new()
	var tool_names := registry.list_tool_names()
	_assert_true(tool_names.has("scene_edit"), "Registry should define scene_edit schema")
	_assert_true(tool_names.has("logic_edit"), "Registry should define logic_edit schema")
	_assert_true(tool_names.has("asset_import"), "Registry should define asset_import schema")
	_assert_true(tool_names.has("visual_generate"), "Registry should define visual_generate schema")
	_assert_true(tool_names.has("playtest"), "Registry should define playtest schema")
	_assert_true(tool_names.has("safety_check"), "Registry should define safety_check schema")

	var scene_invocation := ToolInvocation.new("scene_edit", {"op": "move", "delta": {"x": 1}}, "scene-idem-1")
	var scene_validation := registry.validate_and_apply(scene_invocation)
	_assert_true(scene_validation.get("ok", false), "scene_edit invocation should pass schema validation")
	_assert_true(scene_invocation.is_idempotent, "scene_edit should be tagged idempotent by schema")
	_assert_true(not scene_invocation.requires_approval, "scene_edit should not require parent approval")

	var logic_invocation := ToolInvocation.new("logic_edit", {"rule_id": "rule-1"}, "logic-idem-1")
	var logic_validation := registry.validate_and_apply(logic_invocation)
	_assert_true(logic_validation.get("ok", false), "logic_edit invocation should pass schema validation")
	_assert_true(logic_invocation.is_idempotent, "logic_edit should be tagged idempotent by schema")
	_assert_true(logic_invocation.requires_approval, "logic_edit should require parent approval")

	var missing_id := ToolInvocation.new("scene_edit", {"op": "move"}, "")
	var missing_id_validation := registry.validate_invocation(missing_id)
	_assert_true(
		not missing_id_validation.get("ok", false),
		"Idempotent tools should require invocation_id"
	)

	var nondeterministic := ToolInvocation.new(
		"scene_edit",
		{"callback": Callable(self, "run")},
		"scene-bad-1"
	)
	var nondeterministic_validation := registry.validate_invocation(nondeterministic)
	_assert_true(
		not nondeterministic_validation.get("ok", false),
		"Callable arguments should be rejected as non-deterministic"
	)

	var unknown_tool := ToolInvocation.new("unknown_tool", {}, "unknown-1")
	var unknown_validation := registry.validate_invocation(unknown_tool)
	_assert_true(
		not unknown_validation.get("ok", false),
		"Unknown tools should be rejected by registry"
	)

	var safety_invocation := ToolInvocation.new(
		"safety_check",
		{"text": "To jest bezpieczne.", "mode": "text"},
		"safety-1"
	)
	var safety_validation := registry.validate_and_apply(safety_invocation)
	_assert_true(safety_validation.get("ok", false), "safety_check invocation should validate")
	_assert_true(safety_invocation.is_idempotent, "safety_check should be idempotent")

	var empty_safety := ToolInvocation.new("safety_check", {}, "safety-2")
	var empty_safety_validation := registry.validate_invocation(empty_safety)
	_assert_true(
		not empty_safety_validation.get("ok", false),
		"safety_check should require at least one payload target"
	)

	var visual_invocation := ToolInvocation.new(
		"visual_generate",
		{
			"project_id": "project-1",
			"world_id": "world-1",
			"prompt": "Przyjazny smok",
			"style_preset": "cartoon",
			"preview_only": true,
		},
		"visual-1"
	)
	var visual_validation := registry.validate_and_apply(visual_invocation)
	_assert_true(
		visual_validation.get("ok", false),
		"visual_generate invocation should pass schema validation with required arguments"
	)
	_assert_true(
		not visual_invocation.is_idempotent,
		"visual_generate should be non-idempotent by default"
	)

	var visual_missing := ToolInvocation.new(
		"visual_generate",
		{"project_id": "project-1", "prompt": "x"},
		"visual-2"
	)
	var visual_missing_validation := registry.validate_invocation(visual_missing)
	_assert_true(
		not visual_missing_validation.get("ok", false),
		"visual_generate should reject payloads missing required arguments"
	)

	return _build_result("AIToolRegistry")

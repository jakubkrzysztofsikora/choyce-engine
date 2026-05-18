## Contract test for AIPerformanceReadModel implementations.
class_name AIPerformanceReadModelContractTest
extends PortContractTest


func run() -> Dictionary:
	var impl = AIPerformanceReadModelAdapter.new()

	# Test initial metrics
	var metrics = impl.get_metrics("7d")
	_assert_eq(metrics.get("total_requests"), 0, "Initial requests should be 0")
	_assert_eq(metrics.get("successful_completions"), 0, "Initial completions should be 0")
	_assert_eq(metrics.get("success_rate"), 0.0, "Initial success rate should be 0%")

	# Simulate tool execution
	var tool_event = MockAIAssistanceAppliedEvent.new("world_generator", "2026-03-02T10:00:00Z", "world_generator", 12.0, true)
	impl.update_from_event(tool_event)

	metrics = impl.get_metrics("7d")
	_assert_eq(metrics.get("total_requests"), 1, "Should count tool execution")
	_assert_eq(metrics.get("successful_completions"), 1, "Should count successful execution")
	_assert_eq(metrics.get("success_rate"), 100.0, "Success rate should be 100%")

	var tools = impl.get_tool_statistics(50)
	_assert_eq(tools.size(), 1, "Should track tool statistics")
	_assert_eq(tools[0].get("tool_name"), "world_generator", "Should record tool name")
	_assert_eq(tools[0].get("executions"), 1, "Should count executions")
	_assert_true(tools[0].get("avg_latency_ms") > 0, "Should track latency")

	# Simulate failed tool execution
	var failed_event = MockAIAssistanceAppliedEvent.new("world_generator", "2026-03-02T10:01:00Z", "world_generator", 8.0, false)
	impl.update_from_event(failed_event)

	metrics = impl.get_metrics("7d")
	_assert_eq(metrics.get("total_requests"), 2, "Should count both executions")
	_assert_eq(metrics.get("successful_completions"), 1, "Should count only successful one")
	_assert_eq(metrics.get("success_rate"), 50.0, "Success rate should be 50%")
	_assert_eq(metrics.get("failed_executions"), 1, "Should count failed executions")
	_assert_true(float(metrics.get("avg_latency_ms", 0.0)) > 0.0, "Should maintain average latency")

	tools = impl.get_tool_statistics(50)
	_assert_eq(tools[0].get("executions"), 2, "Should count both executions")
	_assert_eq(tools[0].get("success_rate"), 50.0, "Should calculate success rate")

	# Simulate moderation block
	var block_event = MockSafetyInterventionTriggeredEvent.new("BLOCK", "MODERATION_BLOCK", "Unsafe language", "2026-03-02T10:02:00Z")
	impl.update_from_event(block_event)

	metrics = impl.get_metrics("7d")
	_assert_eq(metrics.get("blocked_by_moderation"), 1, "Should count moderation blocks")
	_assert_eq(metrics.get("moderation_rate"), 50.0, "Should calculate moderation rate as 1/2 requests")

	# Simulate policy gate trigger
	var policy_event = MockSafetyInterventionTriggeredEvent.new("", "", "", "2026-03-02T10:03:00Z")
	impl.update_from_event(policy_event)

	metrics = impl.get_metrics("7d")
	_assert_eq(metrics.get("policy_gates_triggered"), 2, "Should count policy gate triggers (block + policy)")

	# Test multiple tools
	var dialog_event = MockAIAssistanceAppliedEvent.new("dialogue_adapter", "2026-03-02T10:04:00Z", "dialogue_adapter", 15.0, true)
	impl.update_from_event(dialog_event)

	tools = impl.get_tool_statistics(50)
	_assert_eq(tools.size(), 2, "Should track multiple tools")
	_assert_true(tools[0].get("executions") > tools[1].get("executions"), "Should sort by execution count")

	# Data-minimization gate: ad-tech identifiers should be redacted from dashboard outputs.
	impl._metrics["7d"]["advertising_id"] = "ad-123"
	var sanitized_metrics := impl.get_metrics("7d")
	_assert_false(sanitized_metrics.has("advertising_id"), "Metrics payload should remove ad-tech identifiers")

	impl._tool_stats["leaky_tool"] = {
		"tool_name": "leaky_tool",
		"executions": 1,
		"successes": 1,
		"total_latency": 33.0,
		"success_rate": 100.0,
		"avg_latency_ms": 33.0,
		"last_used": "2026-03-02T10:05:00Z",
		"advertising_id": "ad-tool-1",
	}
	var sanitized_tools := impl.get_tool_statistics(50)
	var found_leaky_tool := false
	for tool_variant in sanitized_tools:
		if not (tool_variant is Dictionary):
			continue
		var tool_row: Dictionary = tool_variant
		if tool_row.get("tool_name", "") == "leaky_tool":
			found_leaky_tool = true
			_assert_false(tool_row.has("advertising_id"), "Tool stats row should remove ad-tech identifiers")
	_assert_true(found_leaky_tool, "Leaky tool row should remain queryable after sanitization")

	return _build_result("AIPerformanceReadModel")


# Mock domain events for testing
class MockAIAssistanceAppliedEvent extends DomainEvent:
	var action_id: String
	var tool_name: String
	var latency_ms: float
	var success: bool

	func _init(p_action_id: String, p_timestamp: String, p_tool_name: String = "", p_latency_ms: float = 10.0, p_success: bool = true) -> void:
		super._init("AIAssistanceAppliedEvent", "", p_timestamp)
		action_id = p_action_id
		tool_name = p_tool_name
		latency_ms = p_latency_ms
		success = p_success


class MockSafetyInterventionTriggeredEvent extends DomainEvent:
	var decision_type: String
	var policy_rule: String
	var trigger_context: String

	func _init(p_decision_type: String = "", p_policy_rule: String = "", p_trigger_context: String = "", p_timestamp: String = "") -> void:
		super._init("SafetyInterventionTriggeredEvent", "", p_timestamp)
		decision_type = p_decision_type
		policy_rule = p_policy_rule
		trigger_context = p_trigger_context

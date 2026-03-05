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
	var tool_event = AIToolExecutedEvent.new("world_generator", 250.0, true, "2026-03-02T10:00:00Z")
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
	var failed_event = AIToolExecutedEvent.new("world_generator", 500.0, false, "2026-03-02T10:01:00Z")
	impl.update_from_event(failed_event)

	metrics = impl.get_metrics("7d")
	_assert_eq(metrics.get("total_requests"), 2, "Should count both executions")
	_assert_eq(metrics.get("successful_completions"), 1, "Should count only successful one")
	_assert_eq(metrics.get("success_rate"), 50.0, "Success rate should be 50%")

	tools = impl.get_tool_statistics(50)
	_assert_eq(tools[0].get("executions"), 2, "Should count both executions")
	_assert_eq(tools[0].get("success_rate"), 50.0, "Should calculate success rate")

	# Simulate moderation block
	var block_event = ModeratedContentBlockedEvent.new("child-1", "text", "Unsafe language", "2026-03-02T10:02:00Z")
	impl.update_from_event(block_event)

	metrics = impl.get_metrics("7d")
	_assert_eq(metrics.get("blocked_by_moderation"), 1, "Should count moderation blocks")
	_assert_eq(metrics.get("moderation_rate"), 50.0, "Should calculate moderation rate as 1/2 requests")

	# Simulate policy gate trigger
	var policy_event = PolicyGateTriggeredEvent.new("2026-03-02T10:03:00Z")
	impl.update_from_event(policy_event)

	metrics = impl.get_metrics("7d")
	_assert_eq(metrics.get("policy_gates_triggered"), 1, "Should count policy gate triggers")

	# Test multiple tools
	var dialog_event = AIToolExecutedEvent.new("dialogue_adapter", 100.0, true, "2026-03-02T10:04:00Z")
	impl.update_from_event(dialog_event)

	tools = impl.get_tool_statistics(50)
	_assert_eq(tools.size(), 2, "Should track multiple tools")
	_assert_true(tools[0].get("executions") > tools[1].get("executions"), "Should sort by execution count")

	return _build_result("AIPerformanceReadModel")


# Mock domain events for testing
class AIToolExecutedEvent extends DomainEvent:
	var tool_name: String
	var latency_ms: float
	var success: bool

	func _init(p_tool: String, p_latency: float, p_success: bool, p_timestamp: String) -> void:
		super._init("AIToolExecutedEvent", "", p_timestamp)
		tool_name = p_tool
		latency_ms = p_latency
		success = p_success


class ModeratedContentBlockedEvent extends DomainEvent:
	var child_id: String
	var content_type: String
	var reason: String

	func _init(p_child_id: String, p_type: String, p_reason: String, p_timestamp: String) -> void:
		super._init("ModeratedContentBlockedEvent", "", p_timestamp)
		child_id = p_child_id
		content_type = p_type
		reason = p_reason


class PolicyGateTriggeredEvent extends DomainEvent:
	func _init(p_timestamp: String) -> void:
		super._init("PolicyGateTriggeredEvent", "", p_timestamp)

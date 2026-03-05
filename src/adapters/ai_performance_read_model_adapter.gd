## In-memory adapter for AIPerformanceReadModel.
## Tracks AI orchestration metrics, tool reliability, and moderation rates.
class_name AIPerformanceReadModelAdapter
extends AIPerformanceReadModel


var _metrics: Dictionary = {
	"7d": {
		"total_requests": 0,
		"successful_completions": 0,
		"blocked_by_moderation": 0,
		"failed_executions": 0,
		"avg_latency_ms": 0.0,
		"policy_gates_triggered": 0,
	},
	"30d": {
		"total_requests": 0,
		"successful_completions": 0,
		"blocked_by_moderation": 0,
		"failed_executions": 0,
		"avg_latency_ms": 0.0,
		"policy_gates_triggered": 0,
	},
}

var _tool_stats: Dictionary = {}  # {tool_name: {executions, success_rate, avg_latency_ms, last_used}}
var _event_times: Array = []  # Track event timestamps for window calculations


func get_metrics(window: String = "7d") -> Dictionary:
	var defaults = {
		"window": window,
		"total_requests": 0,
		"successful_completions": 0,
		"success_rate": 0.0,
		"blocked_by_moderation": 0,
		"failed_executions": 0,
		"avg_latency_ms": 0.0,
		"policy_gates_triggered": 0,
		"moderation_rate": 0.0,
	}

	if window not in _metrics:
		return defaults

	var data = _metrics[window]
	var success_rate = 0.0
	if data["total_requests"] > 0:
		success_rate = float(data["successful_completions"]) / float(data["total_requests"]) * 100.0

	var moderation_rate = 0.0
	if data["total_requests"] > 0:
		moderation_rate = float(data["blocked_by_moderation"]) / float(data["total_requests"]) * 100.0

	return {
		"window": window,
		"total_requests": data["total_requests"],
		"successful_completions": data["successful_completions"],
		"success_rate": success_rate,
		"blocked_by_moderation": data["blocked_by_moderation"],
		"failed_executions": data["failed_executions"],
		"avg_latency_ms": data["avg_latency_ms"],
		"policy_gates_triggered": data["policy_gates_triggered"],
		"moderation_rate": moderation_rate,
	}


func get_tool_statistics(limit: int = 50) -> Array:
	var result = []
	var sorted_tools = _tool_stats.values()
	sorted_tools.sort_custom(func(a, b): return a.get("executions", 0) > b.get("executions", 0))

	for i in range(min(limit, sorted_tools.size())):
		var tool = sorted_tools[i]
		result.append({
			"tool_name": tool.get("tool_name", ""),
			"executions": tool.get("executions", 0),
			"success_rate": tool.get("success_rate", 0.0),
			"avg_latency_ms": tool.get("avg_latency_ms", 0.0),
			"last_used": tool.get("last_used", ""),
		})

	return result


func update_from_event(event: DomainEvent) -> void:
	if event == null:
		return
	var event_type := str(event.event_type)
	if event_type == "AIToolExecutedEvent":
		_record_tool_execution(event)
	elif event_type == "ModeratedContentBlockedEvent":
		_record_moderation_block(event)
	elif event_type == "PolicyGateTriggeredEvent":
		_record_policy_gate(event)


func _record_tool_execution(event: DomainEvent) -> void:
	var tool_name := _event_string(event, "tool_name")
	var latency_ms := _event_float(event, "latency_ms")
	var success := _event_bool(event, "success", true)

	# Initialize tool stats if needed
	if tool_name not in _tool_stats:
		_tool_stats[tool_name] = {
			"tool_name": tool_name,
			"executions": 0,
			"successes": 0,
			"total_latency": 0.0,
			"success_rate": 0.0,
			"avg_latency_ms": 0.0,
			"last_used": "",
		}

	var stats = _tool_stats[tool_name]
	stats["executions"] += 1
	stats["total_latency"] += latency_ms
	stats["avg_latency_ms"] = stats["total_latency"] / float(stats["executions"])
	stats["last_used"] = str(event.timestamp)

	if success:
		stats["successes"] += 1

	stats["success_rate"] = float(stats["successes"]) / float(stats["executions"]) * 100.0

	# Update metrics for both windows
	for window in _metrics.keys():
		_metrics[window]["total_requests"] += 1
		if success:
			_metrics[window]["successful_completions"] += 1


func _record_moderation_block(_event: DomainEvent) -> void:
	for window in _metrics.keys():
		_metrics[window]["blocked_by_moderation"] += 1


func _record_policy_gate(_event: DomainEvent) -> void:
	for window in _metrics.keys():
		_metrics[window]["policy_gates_triggered"] += 1


func _event_string(event: Object, field_name: String) -> String:
	var value: Variant = event.get(field_name)
	if value == null:
		return ""
	return str(value)


func _event_float(event: Object, field_name: String) -> float:
	var value: Variant = event.get(field_name)
	if value == null:
		return 0.0
	return float(value)


func _event_bool(event: Object, field_name: String, default_value: bool = false) -> bool:
	var value: Variant = event.get(field_name)
	if value == null:
		return default_value
	return bool(value)

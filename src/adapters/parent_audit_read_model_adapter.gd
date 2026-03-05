## Legacy in-memory adapter for ParentAuditReadModel.
## Maintains parent-facing audit timeline and intervention tracking.
## NOTE: Keep this class_name distinct from the canonical outbound adapter:
## res://src/adapters/outbound/parent_audit_read_model_adapter.gd
class_name LegacyParentAuditReadModelAdapter
extends ParentAuditReadModel


var _events: Array = []  # Chronological list of {event_type, timestamp, description, reason}
var _interventions: Array = []  # High-impact events: {type, timestamp, action, reason}


func get_timeline(
	parent_profile_id: String,
	from_iso: String = "",
	to_iso: String = "",
	limit: int = 100
) -> Array:
	var result = []
	var from_bound := from_iso.strip_edges()
	var to_bound := to_iso.strip_edges()

	for event_data in _events:
		var ts := str(event_data.get("timestamp", "")).strip_edges()
		var after_from := from_bound.is_empty() or ts >= from_bound
		var before_to := to_bound.is_empty() or ts <= to_bound
		if after_from and before_to:
			result.append(event_data)

	result.reverse()
	return result.slice(0, limit)


func get_interventions(parent_profile_id: String, limit: int = 50) -> Array:
	var result = []
	for intervention in _interventions:
		result.append({
			"type": intervention.get("type", ""),
			"timestamp": intervention.get("timestamp", ""),
			"action": intervention.get("action", ""),
			"reason": intervention.get("reason", ""),
			"context": intervention.get("context", {}),
		})

	result.reverse()
	return result.slice(0, limit)


func update_from_event(event: DomainEvent) -> void:
	if event == null:
		return

	var event_type := str(event.event_type)
	var event_timestamp := str(event.timestamp)
	var event_data = {
		"event_type": event_type,
		"timestamp": event_timestamp,
		"event_id": str(event.event_id),
		"description": "",
		"reason": "",
	}

	# Log all events to timeline
	if event_type == "ModeratedContentBlockedEvent":
		var content_type := _event_string(event, "content_type")
		var reason := _event_string(event, "reason")
		event_data["description"] = "Content blocked: unsafe %s" % content_type
		event_data["reason"] = reason
		_events.append(event_data)
		_interventions.append({
			"type": "CONTENT_BLOCK",
			"timestamp": event_timestamp,
			"action": "Blocked unsafe content",
			"reason": reason,
			"context": {"content_type": content_type},
		})
	elif event_type == "PolicyOverriddenEvent":
		var policy_name := _event_string(event, "policy_name")
		var policy_reason := _event_string(event, "reason")
		event_data["description"] = "Policy override: %s" % policy_name
		event_data["reason"] = policy_reason
		_events.append(event_data)
		_interventions.append({
			"type": "POLICY_OVERRIDE",
			"timestamp": event_timestamp,
			"action": "Modified policy: %s" % policy_name,
			"reason": policy_reason,
			"context": {"policy": policy_name},
		})
	elif event_type == "AIToolExecutedEvent":
		var tool_name := _event_string(event, "tool_name")
		event_data["description"] = "AI tool executed: %s" % tool_name
		event_data["reason"] = "Tool: %s" % tool_name
		_events.append(event_data)
	elif event_type == "PublishApprovedEvent":
		var project_id := _event_string(event, "project_id")
		event_data["description"] = "Project published: %s" % project_id
		event_data["reason"] = "Parent approved publication"
		_events.append(event_data)
		_interventions.append({
			"type": "PUBLISH_APPROVED",
			"timestamp": event_timestamp,
			"action": "Approved publication",
			"reason": "Parent approval",
			"context": {"project_id": project_id},
		})
	elif event is DomainEvent:
		# Generic domain event logging
		event_data["description"] = "Event: %s" % event_type
		_events.append(event_data)


func _event_string(event: Object, field_name: String) -> String:
	var value: Variant = event.get(field_name)
	if value == null:
		return ""
	return str(value)

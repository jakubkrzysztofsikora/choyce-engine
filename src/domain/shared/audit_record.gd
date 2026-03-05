## Immutable value object for a tamper-evident audit ledger entry.
## Each record includes a hash linking to the previous record, forming
## a chain that detects retroactive modifications.
class_name AuditRecord
extends RefCounted

var record_id: String
var event_type: String
var event_id: String
var actor_id: String
var timestamp: String  # ISO 8601
var payload: Dictionary
var previous_hash: String
var record_hash: String


func _init(
	p_record_id: String = "",
	p_event_type: String = "",
	p_event_id: String = "",
	p_actor_id: String = "",
	p_timestamp: String = "",
	p_payload: Dictionary = {},
	p_previous_hash: String = ""
) -> void:
	record_id = p_record_id
	event_type = p_event_type
	event_id = p_event_id
	actor_id = p_actor_id
	timestamp = p_timestamp
	payload = p_payload.duplicate()
	previous_hash = p_previous_hash
	record_hash = compute_hash(record_id, event_type, event_id, timestamp, payload, previous_hash)


static func compute_hash(
	p_record_id: String,
	p_event_type: String,
	p_event_id: String,
	p_timestamp: String,
	p_payload: Dictionary,
	p_previous_hash: String
) -> String:
	var data := "%s|%s|%s|%s|%s|%s" % [
		p_record_id,
		p_event_type,
		p_event_id,
		p_timestamp,
		JSON.stringify(p_payload),
		p_previous_hash,
	]
	return data.sha256_text()


static func from_event(
	event: DomainEvent,
	p_record_id: String,
	p_previous_hash: String,
	p_timestamp_override: String = ""
) -> AuditRecord:
	var resolved_timestamp := p_timestamp_override.strip_edges()
	if resolved_timestamp.is_empty():
		resolved_timestamp = event.timestamp
	var event_payload := _extract_payload(event)
	return AuditRecord.new(
		p_record_id,
		event.event_type,
		event.event_id,
		event.actor_id,
		resolved_timestamp,
		event_payload,
		p_previous_hash
	)


static func _extract_payload(event: DomainEvent) -> Dictionary:
	var result := event.payload.duplicate() if not event.payload.is_empty() else {}

	# Include known event-specific fields for common event types.
	for prop in event.get_property_list():
		var name: String = prop.get("name", "")
		if name in ["record_id", "event_type", "event_id", "actor_id",
					"timestamp", "payload", "RefCounted", ""]:
			continue
		if name.begins_with("_") or name.begins_with("script"):
			continue
		if prop.get("usage", 0) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = event.get(name)
			if value is String or value is int or value is float or value is bool:
				result[name] = value
			elif value is Dictionary:
				result[name] = value.duplicate()
			elif value is Array:
				result[name] = value.duplicate()

	return result


func to_dict() -> Dictionary:
	return {
		"record_id": record_id,
		"event_type": event_type,
		"event_id": event_id,
		"actor_id": actor_id,
		"timestamp": timestamp,
		"payload": payload.duplicate(),
		"previous_hash": previous_hash,
		"record_hash": record_hash,
	}


static func from_dict(data: Dictionary) -> AuditRecord:
	var record := AuditRecord.new(
		str(data.get("record_id", "")),
		str(data.get("event_type", "")),
		str(data.get("event_id", "")),
		str(data.get("actor_id", "")),
		str(data.get("timestamp", "")),
		data.get("payload", {}) as Dictionary if data.get("payload") is Dictionary else {},
		str(data.get("previous_hash", ""))
	)
	var stored_hash := str(data.get("record_hash", "")).strip_edges()
	if not stored_hash.is_empty():
		record.record_hash = stored_hash
	return record


func verify() -> bool:
	var expected := compute_hash(record_id, event_type, event_id, timestamp, payload, previous_hash)
	return record_hash == expected

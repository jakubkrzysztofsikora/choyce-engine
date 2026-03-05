## Adapter implementing ParentAuditReadModel.
## Converts domain events into AuditRecords, persists them via AuditLedgerPort,
## and provides parent-facing timeline and intervention queries.
## Supports family linking so parents see their children's events.
class_name ParentAuditReadModelAdapter
extends ParentAuditReadModel

var _ledger: AuditLedgerPort
var _clock: ClockPort
var _record_counter: int = 0

## Maps parent_profile_id -> Array[String] of linked kid profile IDs.
var _family_links: Dictionary = {}


func setup(
	ledger: AuditLedgerPort,
	clock: ClockPort = null
) -> ParentAuditReadModelAdapter:
	_ledger = ledger
	_clock = clock
	_family_links = {}
	_record_counter = 0
	return self


## Registers a parent-to-kid link so get_timeline includes kid events.
func register_family_link(parent_id: String, kid_id: String) -> void:
	if parent_id.strip_edges().is_empty() or kid_id.strip_edges().is_empty():
		return
	if not _family_links.has(parent_id):
		_family_links[parent_id] = []
	var kids: Array = _family_links[parent_id]
	if not kids.has(kid_id):
		kids.append(kid_id)
		_family_links[parent_id] = kids


func get_timeline(
	parent_profile_id: String,
	from_iso: String = "",
	to_iso: String = "",
	limit: int = 100
) -> Array:
	if _ledger == null:
		return []

	var actor_ids := _resolve_family_ids(parent_profile_id)
	var result: Array = []

	for actor_id in actor_ids:
		var filter := {"actor_id": actor_id, "limit": limit}
		if not from_iso.strip_edges().is_empty():
			filter["from_iso"] = from_iso
		if not to_iso.strip_edges().is_empty():
			filter["to_iso"] = to_iso
		var records := _ledger.get_records(filter)
		result.append_array(records)

	# Sort by timestamp ascending and apply limit
	result.sort_custom(_compare_by_timestamp)
	if result.size() > limit:
		result.resize(limit)

	return result


func get_interventions(parent_profile_id: String, limit: int = 50) -> Array:
	if _ledger == null:
		return []

	var actor_ids := _resolve_family_ids(parent_profile_id)
	var result: Array = []

	for actor_id in actor_ids:
		var filter := {
			"actor_id": actor_id,
			"event_type": "SafetyInterventionTriggered",
			"limit": limit,
		}
		var records := _ledger.get_records(filter)
		result.append_array(records)

	result.sort_custom(_compare_by_timestamp)
	if result.size() > limit:
		result.resize(limit)

	return result


func update_from_event(event: DomainEvent) -> void:
	if event == null or _ledger == null:
		return

	_record_counter += 1
	var record_id := "audit-%d-%s" % [_record_counter, event.event_id]
	var prev_hash := _ledger.last_hash()
	var record_timestamp := event.timestamp
	if record_timestamp.strip_edges().is_empty() and _clock != null:
		record_timestamp = _clock.now_iso()

	var record := AuditRecord.from_event(event, record_id, prev_hash, record_timestamp)
	_ledger.append_record(record)


func _resolve_family_ids(parent_profile_id: String) -> Array:
	var ids: Array = [parent_profile_id]
	if _family_links.has(parent_profile_id):
		var kids: Array = _family_links[parent_profile_id]
		for kid_id in kids:
			if not ids.has(kid_id):
				ids.append(kid_id)
	return ids


static func _compare_by_timestamp(a: Variant, b: Variant) -> bool:
	if a is AuditRecord and b is AuditRecord:
		return a.timestamp < b.timestamp
	return false

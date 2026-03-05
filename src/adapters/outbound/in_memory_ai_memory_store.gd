## In-memory adapter for AIMemoryStorePort.
## Used by tests and local development to keep deterministic memory behavior.
class_name InMemoryAIMemoryStore
extends AIMemoryStorePort

var _session_entries: Dictionary = {}
var _project_summaries: Dictionary = {}


func append_session_entry(session_id: String, entry: Dictionary) -> bool:
	if session_id.is_empty() or entry.is_empty():
		return false

	var existing: Array = _session_entries.get(session_id, [])
	var next_entries := existing.duplicate(true)
	next_entries.append(entry.duplicate(true))
	_session_entries[session_id] = next_entries
	return true


func list_session_entries(session_id: String, limit: int = 50) -> Array:
	if session_id.is_empty() or limit <= 0:
		return []
	var entries: Array = _session_entries.get(session_id, [])
	if entries.is_empty():
		return []

	var start := maxi(0, entries.size() - limit)
	var sliced := entries.slice(start, entries.size())
	var cloned: Array = []
	for item in sliced:
		if item is Dictionary:
			cloned.append((item as Dictionary).duplicate(true))
	return cloned


func save_project_summary(project_id: String, summary: Dictionary) -> bool:
	if project_id.is_empty() or summary.is_empty():
		return false
	_project_summaries[project_id] = summary.duplicate(true)
	return true


func load_project_summary(project_id: String) -> Dictionary:
	if project_id.is_empty():
		return {}
	var summary: Variant = _project_summaries.get(project_id, {})
	if summary is Dictionary:
		return (summary as Dictionary).duplicate(true)
	return {}


func clear() -> void:
	_session_entries = {}
	_project_summaries = {}

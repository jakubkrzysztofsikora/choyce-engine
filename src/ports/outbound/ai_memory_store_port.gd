## Outbound port for AI memory persistence.
## Stores short-term session memory and summarized long-term project history.
class_name AIMemoryStorePort
extends RefCounted


func append_session_entry(session_id: String, entry: Dictionary) -> bool:
	push_error("AIMemoryStorePort.append_session_entry() not implemented")
	return false


func list_session_entries(session_id: String, limit: int = 50) -> Array:
	push_error("AIMemoryStorePort.list_session_entries() not implemented")
	return []


func save_project_summary(project_id: String, summary: Dictionary) -> bool:
	push_error("AIMemoryStorePort.save_project_summary() not implemented")
	return false


func load_project_summary(project_id: String) -> Dictionary:
	push_error("AIMemoryStorePort.load_project_summary() not implemented")
	return {}

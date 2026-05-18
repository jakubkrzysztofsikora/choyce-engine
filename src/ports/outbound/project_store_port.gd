## Outbound port contract for project persistence.
## The application layer depends on this interface for save/load/list flows.
class_name ProjectStorePort
extends RefCounted


func save_project(project: Project) -> bool:
	push_error("ProjectStorePort.save_project() not implemented")
	return false


func load_project(project_id: String) -> Project:
	push_error("ProjectStorePort.load_project() not implemented")
	return Project.new()


func list_projects() -> Array:
	push_error("ProjectStorePort.list_projects() not implemented")
	return []


func save_action_log(project_id: String, log_data: Dictionary) -> bool:
	push_error("ProjectStorePort.save_action_log() not implemented")
	return false


func load_action_log(project_id: String) -> Dictionary:
	push_error("ProjectStorePort.load_action_log() not implemented")
	return {}


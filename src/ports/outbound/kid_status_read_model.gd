## Outbound read model port for kid-facing project and progression summaries.
## Implementations provide query-optimized views built from domain events.
class_name KidStatusReadModel
extends RefCounted


func get_project_status(project_id: String, profile_id: String) -> Dictionary:
	push_error("KidStatusReadModel.get_project_status() not implemented")
	return {}


func list_recent_projects(profile_id: String, limit: int = 20) -> Array:
	push_error("KidStatusReadModel.list_recent_projects() not implemented")
	return []


func update_from_event(event: DomainEvent) -> void:
	push_error("KidStatusReadModel.update_from_event() not implemented")

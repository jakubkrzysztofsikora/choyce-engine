## Outbound read model port for parent-facing audit timelines and interventions.
## Aggregates policy, AI, and publishing events for explainable supervision.
class_name ParentAuditReadModel
extends RefCounted


func get_timeline(
	parent_profile_id: String,
	from_iso: String = "",
	to_iso: String = "",
	limit: int = 100
) -> Array:
	push_error("ParentAuditReadModel.get_timeline() not implemented")
	return []


func get_interventions(parent_profile_id: String, limit: int = 50) -> Array:
	push_error("ParentAuditReadModel.get_interventions() not implemented")
	return []


func update_from_event(event: DomainEvent) -> void:
	push_error("ParentAuditReadModel.update_from_event() not implemented")

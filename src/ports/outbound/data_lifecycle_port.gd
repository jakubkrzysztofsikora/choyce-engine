## Outbound port for compliance data lifecycle backend operations.
class_name DataLifecyclePort
extends RefCounted


func enqueue_export(payload: Dictionary) -> Dictionary:
	push_error("DataLifecyclePort.enqueue_export() not implemented")
	return {}


func enqueue_delete(payload: Dictionary) -> Dictionary:
	push_error("DataLifecyclePort.enqueue_delete() not implemented")
	return {}


func update_retention(payload: Dictionary) -> bool:
	push_error("DataLifecyclePort.update_retention() not implemented")
	return false


func get_job(job_id: String) -> Dictionary:
	push_error("DataLifecyclePort.get_job() not implemented")
	return {}

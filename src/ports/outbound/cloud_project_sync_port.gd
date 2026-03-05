## Outbound port for optional cloud synchronization of project snapshots.
## Implementations must be explicit opt-in and can be disabled at runtime.
class_name CloudProjectSyncPort
extends RefCounted


func sync_project(project: Project) -> bool:
	push_error("CloudProjectSyncPort.sync_project() not implemented")
	return false


func is_available() -> bool:
	return false

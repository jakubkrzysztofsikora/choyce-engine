## In-memory adapter for CloudProjectSyncPort.
## Used for contract verification without any network dependency.
class_name InMemoryCloudProjectSync
extends "res://src/ports/outbound/cloud_project_sync_port.gd"

var _is_enabled: bool = true
var _synced: Dictionary = {}
var _sync_order: Array[String] = []


func setup(enabled: bool = true) -> InMemoryCloudProjectSync:
	_is_enabled = enabled
	_synced = {}
	_sync_order = []
	return self


func sync_project(project: Project) -> bool:
	if not _is_enabled:
		return false
	if project == null or project.project_id.strip_edges().is_empty():
		return false

	_synced[project.project_id] = project
	if not _sync_order.has(project.project_id):
		_sync_order.append(project.project_id)
	return true


func is_available() -> bool:
	return _is_enabled


func get_sync_count() -> int:
	return _sync_order.size()


func has_synced(project_id: String) -> bool:
	return _synced.has(project_id)


func get_synced_project_ids() -> Array[String]:
	return _sync_order.duplicate()

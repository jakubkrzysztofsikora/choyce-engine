## In-memory adapter for PublishStorePort.
## Stores publish requests deterministically for tests and offline sessions.
class_name InMemoryPublishStore
extends PublishStorePort

var _requests: Dictionary = {}
var _ordered_ids: Array[String] = []


func setup() -> InMemoryPublishStore:
	_requests = {}
	_ordered_ids = []
	return self


func save_request(request: PublishRequest) -> bool:
	if request == null:
		return false
	if request.request_id.strip_edges().is_empty():
		return false
	_requests[request.request_id] = request
	if not _ordered_ids.has(request.request_id):
		_ordered_ids.append(request.request_id)
	return true


func load_request(request_id: String) -> PublishRequest:
	if request_id.strip_edges().is_empty():
		return null
	var variant: Variant = _requests.get(request_id, null)
	if variant is PublishRequest:
		return variant as PublishRequest
	return null


func list_requests_for_project(project_id: String) -> Array:
	if project_id.strip_edges().is_empty():
		return []
	var results: Array = []
	for request_id in _ordered_ids:
		var req := load_request(request_id)
		if req != null and req.project_id == project_id:
			results.append(req)
	return results


func list_published() -> Array:
	var results: Array = []
	for request_id in _ordered_ids:
		var req := load_request(request_id)
		if req != null and req.state == PublishRequest.PublishState.PUBLISHED:
			results.append(req)
	return results


func clear() -> void:
	_requests = {}
	_ordered_ids = []

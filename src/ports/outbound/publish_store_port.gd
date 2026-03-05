## Outbound port for persisting and loading publish requests.
## Keeps publishing workflow state independent of storage implementation.
class_name PublishStorePort
extends RefCounted


func save_request(request: PublishRequest) -> bool:
	push_error("PublishStorePort.save_request() not implemented")
	return false


func load_request(request_id: String) -> PublishRequest:
	push_error("PublishStorePort.load_request() not implemented")
	return null


func list_requests_for_project(project_id: String) -> Array:
	push_error("PublishStorePort.list_requests_for_project() not implemented")
	return []


func list_published() -> Array:
	push_error("PublishStorePort.list_published() not implemented")
	return []

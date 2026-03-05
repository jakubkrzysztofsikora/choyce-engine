## Inbound port: take down a published world from the family library.
## Only parent profiles can unpublish. The world returns to a revisable state.
class_name UnpublishWorldPort
extends RefCounted


func execute(request_id: String, actor: PlayerProfile, reason: String) -> PublishRequest:
	push_error("UnpublishWorldPort.execute() not implemented")
	return null

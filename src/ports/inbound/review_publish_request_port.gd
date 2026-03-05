## Inbound port: parent reviews (approves or rejects) a pending publish request.
## Only parent profiles can review. On approval the world becomes publishable;
## on rejection the requester can revise and re-submit.
class_name ReviewPublishRequestPort
extends RefCounted


func execute(request_id: String, approved: bool, reviewer: PlayerProfile, reason: String) -> PublishRequest:
	push_error("ReviewPublishRequestPort.execute() not implemented")
	return null

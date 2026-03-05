## Inbound port: initiate publishing a world to the family library.
## Runs content moderation checks and creates a PublishRequest
## that requires parent approval before visibility changes.
class_name PublishToFamilyLibraryPort
extends RefCounted


func execute(project_id: String, world_id: String, requester: PlayerProfile) -> PublishRequest:
	push_error("PublishToFamilyLibraryPort.execute() not implemented")
	return null

## Emitted when a publish request is created and submitted for review.
class_name PublishRequestSubmittedEvent
extends DomainEvent

var request_id: String
var project_id: String
var world_id: String
var requester_id: String
var visibility: String


func _init(p_request_id: String = "", p_actor: String = "", p_timestamp: String = "") -> void:
	super._init("PublishRequestSubmitted", p_actor, p_timestamp)
	request_id = p_request_id
	project_id = ""
	world_id = ""
	requester_id = p_actor
	visibility = "PRIVATE"

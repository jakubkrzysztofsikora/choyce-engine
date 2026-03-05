## Emitted when a parent approves a publish request.
class_name PublishApprovedEvent
extends DomainEvent

var request_id: String
var reviewer_id: String
var visibility: String


func _init(p_request_id: String = "", p_reviewer: String = "", p_timestamp: String = "") -> void:
	super._init("PublishApproved", p_reviewer, p_timestamp)
	request_id = p_request_id
	reviewer_id = p_reviewer
	visibility = ""

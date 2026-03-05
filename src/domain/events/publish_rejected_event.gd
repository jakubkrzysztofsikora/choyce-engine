## Emitted when a parent rejects a publish request.
class_name PublishRejectedEvent
extends DomainEvent

var request_id: String
var reviewer_id: String
var rejection_reason: String


func _init(p_request_id: String = "", p_reviewer: String = "", p_timestamp: String = "") -> void:
	super._init("PublishRejected", p_reviewer, p_timestamp)
	request_id = p_request_id
	reviewer_id = p_reviewer
	rejection_reason = ""

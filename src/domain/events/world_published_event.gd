## Emitted when a world becomes visible in the family library.
class_name WorldPublishedEvent
extends DomainEvent

var request_id: String
var project_id: String
var world_id: String
var visibility: String


func _init(p_request_id: String = "", p_actor: String = "", p_timestamp: String = "") -> void:
	super._init("WorldPublished", p_actor, p_timestamp)
	request_id = p_request_id
	project_id = ""
	world_id = ""
	visibility = ""

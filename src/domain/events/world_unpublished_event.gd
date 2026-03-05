## Emitted when a published world is taken down.
class_name WorldUnpublishedEvent
extends DomainEvent

var request_id: String
var world_id: String
var reason: String


func _init(p_request_id: String = "", p_actor: String = "", p_timestamp: String = "") -> void:
	super._init("WorldUnpublished", p_actor, p_timestamp)
	request_id = p_request_id
	world_id = ""
	reason = ""

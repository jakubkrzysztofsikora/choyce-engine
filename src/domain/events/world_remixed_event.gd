## Domain event: World reset/remixed by player or parent.
## Emitted when progression is cleared for fast remix or difficulty adjustment.
## Used for audit trail and progression milestone tracking.
class_name WorldRemixedEvent
extends DomainEvent


var world_id: String
var profile_id: String


func _init(p_world_id: String, p_profile_id: String, p_timestamp: String = "") -> void:
	super._init(p_timestamp)
	world_id = p_world_id
	profile_id = p_profile_id

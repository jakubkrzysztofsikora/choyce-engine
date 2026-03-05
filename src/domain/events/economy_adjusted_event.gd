## Domain event emitted when parent adjusts game economy.
## Used for audit logging and parent timeline tracking.
class_name EconomyAdjustedEvent
extends DomainEvent


var world_id: String
var adjustments: Array  # Array of {category, name, original, current, description}
var parent_id: String


func _init(
	p_world_id: String = "",
	p_adjustments: Array = [],
	p_parent_id: String = "",
	p_timestamp: String = ""
) -> void:
	super._init("EconomyAdjustedEvent", "", p_timestamp)
	world_id = p_world_id
	adjustments = p_adjustments.duplicate(true) if p_adjustments.size() > 0 else []
	parent_id = p_parent_id

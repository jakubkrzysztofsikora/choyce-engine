## Emitted when a world's scene graph or properties change.
## Carries previous and new state for undo/redo support via
## the event-sourced action log.
class_name WorldEditedEvent
extends DomainEvent

var world_id: String
var edit_type: String  # "node_added", "node_removed", "node_moved", "property_changed"
var target_node_id: String
var previous_state: Dictionary
var new_state: Dictionary


func _init(p_world_id: String = "", p_edit_type: String = "", p_actor: String = "", p_timestamp: String = "") -> void:
	super._init("WorldEdited", p_actor, p_timestamp)
	world_id = p_world_id
	edit_type = p_edit_type
	target_node_id = ""
	previous_state = {}
	new_state = {}

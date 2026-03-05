## Value object describing a single edit operation on a world's scene graph.
## Carries the action type, target node, and before/after state to support
## undo via the event-sourced action log.
class_name WorldEditCommand
extends RefCounted

enum Action {
	ADD_NODE,
	REMOVE_NODE,
	MOVE_NODE,
	DUPLICATE_NODE,
	CHANGE_PROPERTY,
	PAINT,
}

var action: Action
var target_node_id: String
var node_data: Dictionary
var previous_state: Dictionary
var new_state: Dictionary


func _init(p_action: Action = Action.ADD_NODE, p_target: String = "") -> void:
	action = p_action
	target_node_id = p_target
	node_data = {}
	previous_state = {}
	new_state = {}


func is_destructive() -> bool:
	return action == Action.REMOVE_NODE

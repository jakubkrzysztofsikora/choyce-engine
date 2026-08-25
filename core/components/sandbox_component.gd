class_name SandboxComponent
extends Node
## Base for every drop-on-anything component.
##
## Contract (see architecture doc §5.2):
##   1. never reach up into a concrete owner type
##   2. talk to siblings only through Components.get_comp()
##   3. self-register on _ready, deregister on _exit_tree
##   4. all tuning lives in an exported Resource, not scattered @export vars
##   5. testable headless — no viewport, no specific parent type required

var entity: Node


func _component_key() -> StringName:
	push_error("%s must override _component_key()" % get_script().resource_path)
	return &""


func _ready() -> void:
	entity = get_parent()
	Components.register(entity, _component_key(), self)
	_on_registered()


func _exit_tree() -> void:
	Components.unregister(entity, _component_key())


## Override instead of _ready in subclasses so registration always happens first.
func _on_registered() -> void:
	pass


func sibling(key: StringName) -> Node:
	return Components.get_comp(entity, key)


func entity_3d() -> Node3D:
	return entity as Node3D

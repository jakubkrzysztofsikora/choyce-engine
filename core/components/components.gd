class_name Components
extends RefCounted
## Component resolver.
##
## Deliberately metadata-based rather than inheritance-based. A component's
## owner is a RigidBody3D / CharacterBody3D / StaticBody3D / whatever, so the
## owner cannot be forced to extend a common base class. Metadata sidesteps that
## entirely and stays O(1).
##
## Rules enforced by this design:
##   - a component NEVER does get_node("../Something"); renames break that.
##   - a component NEVER reaches up into a concrete owner type.
##   - lookup is always Components.get_comp(entity, &"health").

const META_PREFIX := "comp_"
const META_ENTITY := "sandbox_entity"

## Well-known keys. Use these constants, never raw strings at call sites.
const HEALTH := &"health"
const HURTBOX := &"hurtbox"
const TEAM := &"team"
const INTERACTABLE := &"interactable"
const GRAB := &"grab"
const DESTRUCTIBLE := &"destructible"
const HIGHLIGHT := &"highlight"
const FX := &"fx"
const PLACEABLE := &"placeable"
const PLACED_BLOCK := &"placed_block"


static func register(entity: Node, key: StringName, comp: Node) -> void:
	if entity == null:
		return
	entity.set_meta(META_ENTITY, true)
	entity.set_meta(META_PREFIX + String(key), comp)


static func unregister(entity: Node, key: StringName) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	var m := META_PREFIX + String(key)
	if entity.has_meta(m):
		entity.remove_meta(m)


static func get_comp(entity: Node, key: StringName) -> Node:
	if entity == null or not is_instance_valid(entity):
		return null
	var m := META_PREFIX + String(key)
	if not entity.has_meta(m):
		return null
	var c = entity.get_meta(m)
	return c if is_instance_valid(c) else null


static func has(entity: Node, key: StringName) -> bool:
	return get_comp(entity, key) != null


## Walks up from any node to the nearest registered entity root.
## Lets a raycast hit on a child collider resolve to the thing that owns it.
static func entity_of(node: Node) -> Node:
	var n := node
	while n != null:
		if n.has_meta(META_ENTITY):
			return n
		n = n.get_parent()
	return null


static func is_entity(node: Node) -> bool:
	return node != null and node.has_meta(META_ENTITY)

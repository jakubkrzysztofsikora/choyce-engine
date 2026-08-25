class_name HurtboxComponent
extends Area3D
## An Area3D that routes DamageInfo to a HealthComponent.
##
## Not a SandboxComponent because it must BE an Area3D (Godot has no multiple
## inheritance). It self-registers with the same Components registry so the rest
## of the kit cannot tell the difference.
##
## Separate from health so one entity can carry several hurtboxes with different
## multipliers (head 2.0x, body 1.0x, leg 0.7x).

enum Faction { NPC, PLAYER }

@export var multiplier: float = 1.0
## Explicit, NOT inferred from a group. Children _ready() before their parent,
## so `entity.is_in_group("players")` was always false here — every player
## hurtbox was silently tagged NPC_HURTBOX and every layer-based PvP or
## NPC-targeting query hit the wrong set.
@export var faction: Faction = Faction.NPC
## Where to send damage. Empty = the parent entity.
## SECURITY: never populate this from a save file. NodePath decodes fully even
## with full_objects = false, so a data-driven NodePath here would be a
## get_node() gadget.
@export var health_entity_path: NodePath

var entity: Node


func _ready() -> void:
	entity = get_parent()
	Components.register(entity, Components.HURTBOX, self)
	collision_layer = Layers.PLAYER_HURTBOX if faction == Faction.PLAYER else Layers.NPC_HURTBOX
	collision_mask = 0        # hurtboxes are queried, they do not query
	monitoring = false        # nothing to monitor; weapons query us
	monitorable = true


func _exit_tree() -> void:
	Components.unregister(entity, Components.HURTBOX)


## Single entry point for all harm. Weapons call this, never HealthComponent.
func take(info: DamageInfo) -> bool:
	if info == null:
		return false
	var target: Node = entity
	if not health_entity_path.is_empty():
		target = get_node_or_null(health_entity_path)
	var health := Components.get_comp(target, Components.HEALTH) as HealthComponent
	if health == null:
		return false
	var scaled: DamageInfo = info.duplicate()
	scaled.hitbox_multiplier = info.hitbox_multiplier * multiplier
	health.apply(scaled)
	return true


## Convenience for a raycast/shapecast hit: resolves any collider to a hurtbox.
static func deliver(collider: Node, info: DamageInfo) -> bool:
	if collider == null:
		return false
	if collider is HurtboxComponent:
		return (collider as HurtboxComponent).take(info)
	var ent := Components.entity_of(collider)
	var hb := Components.get_comp(ent, Components.HURTBOX) as HurtboxComponent
	if hb:
		return hb.take(info)
	# No hurtbox: fall back to a bare HealthComponent (blocks, props).
	var health := Components.get_comp(ent, Components.HEALTH) as HealthComponent
	if health:
		health.apply(info)
		return true
	return false

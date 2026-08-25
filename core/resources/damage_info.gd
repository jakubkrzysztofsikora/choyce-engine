class_name DamageInfo
extends Resource
## The single currency of harm in the sandbox.
##
## A weapon never touches HealthComponent. It emits one of these into a
## HurtboxComponent, which routes it. That indirection is exactly why the same
## damage code works on a player, an NPC, a placed block, a prop and a vehicle.

enum Type { GENERIC, IMPACT, EXPLOSIVE, FIRE, FALL, BUILD_TOOL }

@export var amount: float = 0.0
@export var type: Type = Type.GENERIC
@export var source_player_id: int = -1   ## -1 == world / no player
@export var source_team: int = -1
@export var impact_point: Vector3 = Vector3.ZERO
@export var impact_normal: Vector3 = Vector3.UP
@export var impulse: Vector3 = Vector3.ZERO
@export var hitbox_multiplier: float = 1.0


static func make(p_amount: float, p_type: Type = Type.GENERIC,
		p_player: int = -1, p_point: Vector3 = Vector3.ZERO,
		p_normal: Vector3 = Vector3.UP) -> DamageInfo:
	var d := DamageInfo.new()
	d.amount = p_amount
	d.type = p_type
	d.source_player_id = p_player
	d.impact_point = p_point
	d.impact_normal = p_normal
	return d


func final_amount() -> float:
	return amount * hitbox_multiplier

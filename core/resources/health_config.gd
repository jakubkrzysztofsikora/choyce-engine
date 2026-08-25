class_name HealthConfig
extends Resource
## Shared balance data. One config Resource can back 200 props; edit once.

@export var max_health: float = 100.0
@export var invulnerable: bool = false
@export var friendly_fire: bool = false
## Damage below this is ignored entirely — stops debris nudges chipping things.
@export var damage_threshold: float = 0.5
## Multiplier per damage type, indexed by DamageInfo.Type.
@export var type_multipliers: PackedFloat32Array = PackedFloat32Array(
	[1.0, 1.0, 1.5, 1.0, 1.0, 4.0])

## Typed melee hit volume. Replaces the duck-typed
## `_player_ref.has_method("apply_damage_from_enemy")` +
## `get_nodes_in_group("enemies")` per-frame scan that was the
## race-vector flagged across multiple adversary rounds.
##
## Lifecycle:
##   _ready → monitoring = false (off by default — must be enabled
##            explicitly by the AnimationTree Method Call Track or
##            a manual `enable()` call at swing-peak).
##   enable() → monitoring = true; clears the per-swing already-hit
##              set so a fresh swing can land on the same target
##              again next time (e.g. boss tanking multiple hits).
##   disable() → monitoring = false.
##
## On overlap with a HurtArea3D, the HurtArea3D filters + emits
## `hurt(damage, source)` to its parent controller. HitArea3D
## emits `landed(target, damage, knockback)` so the attacker can
## react (e.g. spawn impact VFX, play SFX).
class_name HitArea3D
extends Area3D


signal landed(target: Node, damage: int, knockback: Vector3)


@export var damage: int = 1
@export var knockback_strength: float = 0.0


## Targets already hit by this swing — cleared on enable() so the
## kid swings again and re-hits. Per-swing guard kills the
## "double-hit on rapid overlap" race the loot_pickup boolean flag
## pattern solved earlier this session.
var _already_hit: Array = []


func _ready() -> void:
	monitoring = false


func enable() -> void:
	_already_hit.clear()
	monitoring = true


func disable() -> void:
	monitoring = false


## Internal — called by paired HurtArea3D when it accepts a hit.
## Skips duplicates per swing. Returns true if the hit registered.
func register_hit(target: Node) -> bool:
	if _already_hit.has(target):
		return false
	_already_hit.append(target)
	var knockback := Vector3.ZERO
	if target is Node3D:
		var dir := ((target as Node3D).global_position - global_position).normalized()
		dir.y = 0.0
		knockback = dir * knockback_strength
	landed.emit(target, damage, knockback)
	return true

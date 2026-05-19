## Typed melee hurt volume. Paired with HitArea3D. Listens for
## `area_entered` and emits `hurt(amount, source)` to its parent
## controller so the controller can route into HealthState +
## emit the existing damaged_with_amount signal for HUD numbers.
##
## See HitArea3D for lifecycle. HurtArea3D is always-on (no
## enable/disable) — kid is always damageable, enemies always
## damageable.
class_name HurtArea3D
extends Area3D


## Emitted when a HitArea3D overlaps + registers the hit.
##   amount: int    — damage to apply
##   source: Vector3 — world-space origin of the hit (for knockback)
signal hurt(amount: int, source: Vector3)


func _ready() -> void:
	monitoring = true
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func _on_area_entered(other: Area3D) -> void:
	if not (other is HitArea3D):
		return
	var hit_area: HitArea3D = other
	# HitArea3D maintains the per-swing already-hit set; ask it to
	# register us. Duplicates within one swing return false → no
	# damage, no signal.
	if not hit_area.register_hit(self):
		return
	hurt.emit(hit_area.damage, hit_area.global_position)

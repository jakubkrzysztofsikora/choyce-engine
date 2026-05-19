## Owns the kid-safe damage cap (Adv 1 H2 — used to live on
## HealthState which is now a raw mechanical primitive). Pure
## RefCounted, hex-clean, no Godot types.
##
## Caller passes raw damage + target max_hp; service returns the
## effective amount that should land. Cap is max_hp/3 per single hit
## so a kid never loses more than a third of HP in one frame even
## from multi-source contact damage.
class_name CombatService
extends RefCounted

const DEFAULT_KID_CAP_DIVISOR := 3


## Effective damage = min(raw, max_hp / cap_divisor). cap_divisor 0
## or negative = no cap (adult mode; not used in MVP).
func compute_damage(raw: int, target_max_hp: int, cap_divisor: int = DEFAULT_KID_CAP_DIVISOR) -> int:
	var amount := maxi(raw, 0)
	if cap_divisor <= 0:
		return amount
	var cap := maxi(int(target_max_hp / cap_divisor), 1)
	return mini(amount, cap)

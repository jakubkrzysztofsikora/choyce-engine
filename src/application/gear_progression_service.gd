## Owns the gear-upgrade ladder. Reads Array[GearTierResource], checks
## inventory + xp_level against each tier's recipe + unlock_level, and
## emits "tier_unlocked" with the index of the new tier when the kid
## clears a threshold.
##
## Adv 1 H1 fix: this used to live as `_weapon_tiers` Array literal +
## `_try_auto_upgrade_weapon` method inside gameplay_runtime.gd. Now
## a pure RefCounted application service.
##
## Hex-clean — no Godot Node, no signals. Caller (gameplay_runtime)
## polls or feeds events; service returns the next-tier index or -1.
class_name GearProgressionService
extends RefCounted


## Returns the index of the NEXT tier the kid is eligible for given
## current inventory + xp_level + current_tier_index, or -1 if no
## upgrade ready. Does NOT consume materials — caller decides whether
## to commit (so we can offer a confirm UI later).
func next_eligible_tier(
	tiers: Array,
	inventory: Dictionary,
	xp_level: int,
	current_tier_index: int
) -> int:
	if tiers.is_empty():
		return -1
	if current_tier_index >= tiers.size() - 1:
		return -1
	for i in range(current_tier_index + 1, tiers.size()):
		var tier: GearTierResource = tiers[i]
		if tier == null:
			continue
		if xp_level < tier.unlock_level:
			# Don't skip locked tiers — stop here so upgrading to
			# tier+2 still requires reaching tier+1 first.
			return -1
		if _can_afford(inventory, tier.recipe):
			return i
	return -1


## Mutate inventory in place: subtract recipe inputs from inventory
## counts. Caller is responsible for committing to storage. Returns
## true on success, false if the recipe is unaffordable (shouldn't
## happen if called after next_eligible_tier confirms).
func consume_materials(inventory: Dictionary, recipe: Dictionary) -> bool:
	if not _can_afford(inventory, recipe):
		return false
	for key in recipe.keys():
		inventory[key] = int(inventory.get(key, 0)) - int(recipe[key])
	return true


# ---- internals ----

func _can_afford(inventory: Dictionary, recipe: Dictionary) -> bool:
	for key in recipe.keys():
		if int(inventory.get(key, 0)) < int(recipe[key]):
			return false
	return true

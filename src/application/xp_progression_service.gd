## XP curve + level-up math. Pure RefCounted, no Godot types.
## Adv 4 ROI 2: per-kill XP feedback fixes the "no dopamine" complaint.
##
## Curve from procedural-research:
##   xp_required(level) = int(pow(level, 1.8) + level * 4)
##
## Per-kill XP defaults: slime_green=8, bouncer_pink=12, slime_blue=14.
## Caller can override per-archetype via Dictionary[enemy_id, int].
class_name XpProgressionService
extends RefCounted

const DEFAULT_KILL_XP := {
	"slime_green": 8,
	"slime_blue": 14,
	"bouncer_pink": 12,
	"big_slime": 30,
}


## XP needed to advance from `level` to `level + 1`. Level 0 → 1
## needs 4; level 5 → 6 needs ~37; level 10 → 11 needs ~103.
func xp_required(level: int) -> int:
	if level <= 0:
		return 4
	return int(pow(float(level), 1.8) + level * 4)


## How much XP this kill grants. Falls back to 5 for unknown
## enemy_ids so an unmapped archetype still drips dopamine.
func xp_for_kill(enemy_id: String, overrides: Dictionary = {}) -> int:
	if overrides.has(enemy_id):
		return int(overrides[enemy_id])
	return int(DEFAULT_KILL_XP.get(enemy_id, 5))


## Apply XP gain. Returns the new {level, xp_into_level} pair.
## Handles multi-level skips when kid clears a big chunk at once
## (e.g. boss defeat) by repeatedly subtracting required amounts.
func apply_gain(current_level: int, current_xp: int, gain: int) -> Dictionary:
	var lvl := current_level
	var xp := current_xp + maxi(gain, 0)
	while true:
		var needed := xp_required(lvl)
		if xp < needed:
			break
		xp -= needed
		lvl += 1
	return {"level": lvl, "xp": xp}

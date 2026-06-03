## Domain value object: a non-player character that lives inside a world.
## Pure RefCounted — framework-agnostic so the rules runtime and the
## Godot scene adapter can both consume it.
##
## Three roles, mapped onto the kid-game NPC archetypes:
##   ROLE_GUIDE   — friendly quest-giver / coach. Speaks greeting on
##                  approach, hint on idle, celebration on goal_met.
##   ROLE_VENDOR  — trades inventory items for score (Tycoon, Farm).
##   ROLE_HOSTILE — enemy NPC reused by EnemyController (Adventure).
##
## Hostility is parent-tunable via ParentalControlPolicy.combat_enabled;
## a ROLE_HOSTILE NPC instantiated under a combat-off policy degrades
## to ROLE_GUIDE so a 5yo doesn't get jump-scared.
class_name NPCCharacter
extends RefCounted

const ROLE_GUIDE := "guide"
const ROLE_VENDOR := "vendor"
const ROLE_HOSTILE := "hostile"

const _ALL_ROLES := [ROLE_GUIDE, ROLE_VENDOR, ROLE_HOSTILE]

var npc_id: String
var role: String
## Polish display name shown in the dialog bubble.
var name_pl: String
## Lines keyed by trigger: "greeting", "hint", "celebration".
## Empty string is a valid value — adapter just skips speaking.
var lines_pl: Dictionary
## Optional mesh / sprite id resolved by the visual adapter.
var visual_id: String


func _init(
	p_npc_id: String = "",
	p_role: String = ROLE_GUIDE,
	p_name_pl: String = "",
	p_lines_pl: Dictionary = {},
	p_visual_id: String = "",
) -> void:
	npc_id = p_npc_id
	role = p_role if is_valid_role(p_role) else ROLE_GUIDE
	name_pl = p_name_pl
	lines_pl = p_lines_pl.duplicate(true)
	visual_id = p_visual_id


## Resolve the Polish line for a trigger ("greeting", "hint",
## "celebration"). Returns "" when missing — adapter callers must
## guard against empty strings (don't speak an empty bubble).
##
## Accepts both bare and "_pl"-suffixed keys so the dialogue JSON
## (greeting_pl / hint_pl / celebration_pl) and direct in-memory
## fixtures (greeting) both resolve.
func line_for(trigger: String) -> String:
	for key in [trigger, "%s_pl" % trigger]:
		var raw: Variant = lines_pl.get(key, null)
		if raw is String and not (raw as String).is_empty():
			return raw
	return ""


## Defensive copy: domain types stay immutable from the caller's view
## by handing back a fresh dict so external mutation doesn't leak.
func snapshot_lines() -> Dictionary:
	return lines_pl.duplicate(true)


static func is_valid_role(r: String) -> bool:
	return r in _ALL_ROLES


## Kid-safety degradation: caller passes the active parental policy
## flags. When combat is off, a hostile NPC degrades to a guide so the
## scene still has a friendly character there but doesn't attack.
func degraded_for_combat_off() -> NPCCharacter:
	if role != ROLE_HOSTILE:
		return self
	return NPCCharacter.new(
		npc_id, ROLE_GUIDE, name_pl, lines_pl, visual_id
	)

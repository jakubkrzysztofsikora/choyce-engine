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

## Psychology-backed personality traits (Big Five / OCEAN model)
## Normalized from 0.0 (low) to 1.0 (high)
var openness: float = 0.5
var conscientiousness: float = 0.5
var extraversion: float = 0.5
var agreeableness: float = 0.5
var neuroticism: float = 0.5

## Dark Triad traits
## Normalized from 0.0 (low) to 1.0 (high)
var machiavellianism: float = 0.0
var narcissism: float = 0.0
var psychopathy: float = 0.0

## Dynamic emotional states driven by gameplay and interaction
var happiness: float = 0.5
var irritability: float = 0.2
var anxiety: float = 0.1


func _init(
	p_npc_id: String = "",
	p_role: String = ROLE_GUIDE,
	p_name_pl: String = "",
	p_lines_pl: Dictionary = {},
	p_visual_id: String = "",
	p_openness: float = 0.5,
	p_conscientiousness: float = 0.5,
	p_extraversion: float = 0.5,
	p_agreeableness: float = 0.5,
	p_neuroticism: float = 0.5,
	p_machiavellianism: float = 0.0,
	p_narcissism: float = 0.0,
	p_psychopathy: float = 0.0
) -> void:
	npc_id = p_npc_id
	role = p_role if is_valid_role(p_role) else ROLE_GUIDE
	name_pl = p_name_pl
	lines_pl = p_lines_pl.duplicate(true)
	visual_id = p_visual_id
	openness = p_openness
	conscientiousness = p_conscientiousness
	extraversion = p_extraversion
	agreeableness = p_agreeableness
	neuroticism = p_neuroticism
	machiavellianism = p_machiavellianism
	narcissism = p_narcissism
	psychopathy = p_psychopathy


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
	var copy := NPCCharacter.new(
		npc_id, ROLE_GUIDE, name_pl, lines_pl, visual_id,
		openness, conscientiousness, extraversion, agreeableness, neuroticism,
		machiavellianism, narcissism, psychopathy
	)
	copy.happiness = happiness
	copy.irritability = irritability
	copy.anxiety = anxiety
	return copy


## Update emotional states reactively based on player and world context
func update_emotional_state(player_hp_ratio: float, player_score: int) -> void:
	if player_hp_ratio < 0.4:
		if psychopathy > 0.4:
			# Psychopathic/hostile character is amused by player's distress
			happiness = clampf(happiness + 0.3 * psychopathy, 0.0, 1.0)
			anxiety = clampf(anxiety - 0.2 * psychopathy, 0.0, 1.0)
		elif agreeableness > 0.6:
			# Empathetic character becomes worried/anxious
			anxiety = clampf(anxiety + 0.3, 0.0, 1.0)
			happiness = clampf(happiness - 0.2, 0.0, 1.0)
	else:
		# Gradually return anxiety/happiness to baseline
		anxiety = clampf(anxiety - 0.1, 0.0, 1.0)

	if player_score > 50:
		if narcissism > 0.5:
			# Narcissistic character becomes highly irritated/jealous of player's achievements
			irritability = clampf(irritability + 0.3 * narcissism, 0.0, 1.0)
		elif role == ROLE_HOSTILE:
			# Hostile character gets moderately irritated by player success
			irritability = clampf(irritability + 0.2, 0.0, 1.0)
		else:
			# Friendly gets happy for the player
			happiness = clampf(happiness + 0.1, 0.0, 1.0)

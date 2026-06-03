## Application service: loads NPC roster + dialogue lines from
## `res://data/templates/npc_dialogue.json` and instantiates
## NPCCharacter value objects per template.
##
## Roles are inferred from the npc_id prefix because the JSON shape is
## flat (greeting/hint/celebration only). Mapping table is the single
## source of truth and stays inside this service so the JSON can stay
## human-editable by content authors.
class_name NPCDialogueLoader
extends RefCounted

const _DIALOGUE_PATH := "res://data/templates/npc_dialogue.json"

## npc_id -> role. Anything not in the table defaults to ROLE_GUIDE
## (kid-safe default). Hostile NPCs are explicit so adding a new
## friendly NPC never accidentally aggros the kid.
const _ROLE_MAP := {
	"npc_pirate": NPCCharacter.ROLE_HOSTILE,
	"npc_robot": NPCCharacter.ROLE_GUIDE,
	"npc_coach": NPCCharacter.ROLE_GUIDE,
	"npc_shopkeeper": NPCCharacter.ROLE_VENDOR,
	"npc_banker": NPCCharacter.ROLE_VENDOR,
	"npc_baker": NPCCharacter.ROLE_VENDOR,
	"npc_merchant": NPCCharacter.ROLE_VENDOR,
	"npc_farmer": NPCCharacter.ROLE_GUIDE,
	"npc_scarecrow": NPCCharacter.ROLE_GUIDE,
	"npc_explorer": NPCCharacter.ROLE_GUIDE,
	"npc_parrot": NPCCharacter.ROLE_GUIDE,
	"npc_mayor": NPCCharacter.ROLE_GUIDE,
}

## Friendly display names. Adapter falls back to npc_id when missing.
const _NAME_MAP := {
	"npc_explorer": "Odkrywca Olek",
	"npc_pirate": "Pirat Pablo",
	"npc_parrot": "Papuga Pestka",
	"npc_robot": "Robot-Pomocnik",
	"npc_coach": "Trener",
	"npc_shopkeeper": "Sklepikarz",
	"npc_banker": "Bankier",
	"npc_baker": "Cukiernik",
	"npc_merchant": "Handlarz",
	"npc_farmer": "Rolnik",
	"npc_scarecrow": "Strach na wróble",
	"npc_mayor": "Burmistrz",
}

var _cache: Dictionary = {}   ## template_id -> Array[NPCCharacter]
var _raw_loaded: bool = false
var _raw_data: Dictionary = {}


## Returns Array[NPCCharacter] for the given template. Caches so
## repeated calls (every session start) are cheap. Bad/missing JSON
## returns an empty array — fail-closed (no fake NPCs).
func load_npcs_for_template(template_id: String) -> Array:
	if _cache.has(template_id):
		return _cache[template_id]

	_ensure_raw_loaded()
	var per_template_raw: Variant = _raw_data.get(template_id, null)
	if not (per_template_raw is Dictionary):
		_cache[template_id] = []
		return []

	var per_template: Dictionary = per_template_raw
	var npcs: Array = []
	for npc_id in per_template.keys():
		var lines_variant: Variant = per_template[npc_id]
		if not (lines_variant is Dictionary):
			continue
		var lines: Dictionary = lines_variant
		var role: String = _ROLE_MAP.get(npc_id, NPCCharacter.ROLE_GUIDE)
		var name_pl: String = _NAME_MAP.get(npc_id, String(npc_id))
		npcs.append(NPCCharacter.new(
			String(npc_id),
			role,
			name_pl,
			lines,
			String(npc_id),  # visual_id falls back to npc_id; adapter resolves
		))
	_cache[template_id] = npcs
	return npcs


## Apply parental combat policy: hostile NPCs degrade to guides when
## combat is off. Returns a fresh Array — callers can keep the
## original roster for parent-zone display.
func filtered_for_policy(npcs: Array, combat_enabled: bool) -> Array:
	var out: Array = []
	for npc in npcs:
		if not (npc is NPCCharacter):
			continue
		if not combat_enabled:
			out.append(npc.degraded_for_combat_off())
		else:
			out.append(npc)
	return out


func _ensure_raw_loaded() -> void:
	if _raw_loaded:
		return
	_raw_loaded = true
	var file := FileAccess.open(_DIALOGUE_PATH, FileAccess.READ)
	if file == null:
		push_warning("NPCDialogueLoader: npc_dialogue.json not found at %s" % _DIALOGUE_PATH)
		_raw_data = {}
		return
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK:
		push_warning("NPCDialogueLoader: failed to parse npc_dialogue.json")
		_raw_data = {}
		return
	var parsed: Variant = json.data
	_raw_data = parsed if parsed is Dictionary else {}

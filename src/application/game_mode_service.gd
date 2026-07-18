## GameModeService — Minecraft Bedrock-parity input mode resolver.
##
## Single input set across all of choyce-engine. The "mode" is derived
## from what's in the player's active hotbar slot — no toggle button,
## no mode-switch key. Matches what a 7yo Roblox/Minecraft player
## already knows: hold a sword, LMB attacks; hold a block, LMB breaks.
##
## Per Adv 5 #1 mouse-rebind concern + input research synthesis
## 2026-05-19: dissolves the "left-mouse should be break, not attack"
## debate. Both bindings stay; the runtime routes them based on
## current mode.
##
## Hex-clean: pure RefCounted, no Godot types. PlayerController calls
## `current_mode(hotbar_slot_kind)` once per LMB / RMB tick and routes
## the input action accordingly.
class_name GameModeService
extends RefCounted

enum Mode {
	BUILD,    ## block in active slot → LMB=break, RMB=place
	COMBAT,   ## weapon in active slot → LMB=attack, RMB=camera
	TOOL,     ## axe/pickaxe → LMB=use matching resource tool
	NEUTRAL,  ## nothing held (or unknown id) → LMB=attack (safer default)
}


## Resolve the current mode from the active hotbar entry. The caller
## passes the block_id (or weapon_id) string — empty string = neutral.
## BlockKind catalog drives the build-mode decision: any kid_safe
## block id in BlockKind.default_catalog() → BUILD. Anything else
## (sword tier ids, "fist", etc.) → COMBAT.
func current_mode(active_slot_kind: String) -> Mode:
	if active_slot_kind == "":
		return Mode.NEUTRAL
	if _is_block_kind(active_slot_kind):
		return Mode.BUILD
	if _is_weapon_kind(active_slot_kind):
		return Mode.COMBAT
	if _is_tool_kind(active_slot_kind):
		return Mode.TOOL
	return Mode.NEUTRAL


## LMB action for the current mode. Returns a stable string the
## PlayerController matches on. Kept here (not on PlayerController)
## so future modes (tool/ranged/spell) plug in without touching the
## adapter — Adv 1 hex-arch direction.
func lmb_action_for(mode: Mode) -> String:
	match mode:
		Mode.BUILD:
			return "break_block"
		Mode.COMBAT:
			return "attack"
		Mode.TOOL:
			return "use_tool"
		_:
			return "attack"   ## fallback: empty hand still swings


func rmb_action_for(mode: Mode) -> String:
	match mode:
		Mode.BUILD:
			return "place_block"
		Mode.COMBAT, _:
			return "camera_look"


# ---- internals ----

func _is_block_kind(s: String) -> bool:
	# Match against BlockKind.default_catalog() ids. Keep this list
	# in sync; future migration to BlockCatalogPort (research §arch)
	# removes the duplication.
	const BLOCK_IDS := [
		"grass", "dirt", "wood_oak", "stone", "sand",
		"brick_red", "glow", "spring", "tree_oak", "ore_node",
	]
	return s in BLOCK_IDS


func _is_weapon_kind(s: String) -> bool:
	# Weapon tier ids from gear ladder. Same comment as above — will
	# move to GearCatalogPort lookup once gear is Resource-ified.
	const WEAPON_IDS := [
		"fist", "stick", "sword_iron", "sword_epic",
	]
	return s in WEAPON_IDS


func _is_tool_kind(s: String) -> bool:
	return s in ["tool_axe", "tool_pickaxe"]

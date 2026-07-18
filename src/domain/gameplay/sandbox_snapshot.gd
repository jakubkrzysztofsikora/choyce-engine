## Immutable snapshot of the active sandbox state for local persistence.
## Captures player position, health, inventory, placed blocks, score,
## weapons, XP, wave progress and session timing so the player can
## resume exactly where they left off.  Serialises to/from a plain
## Dictionary so the adapter layer can persist it as JSON without
## pulling in any Godot resource machinery.
class_name SandboxSnapshot
extends RefCounted

const CURRENT_FORMAT_VERSION := 1

## --- player ---
var player_position: Vector3 = Vector3.ZERO
var player_health_current: int = 100
var player_health_max: int = 100

## --- inventory ---
## Keys are item-kind IDs, values are stack counts.
var inventory_items: Dictionary = {}

## --- world blocks ---
## Each entry: {"cell": [x, y, z], "kind_id": "<block kind>"}
var placed_blocks: Array = []

## --- progression ---
var score: int = 0
var weapon_index: int = 0
var xp_level: int = 1
var xp_current: int = 0
var wave_number: int = 0

## --- session ---
var session_elapsed_sec: float = 0.0

## --- identity ---
var world_id: String = ""
var project_id: String = ""
var profile_id: String = ""

## --- metadata ---
var saved_at_iso: String = ""
var format_version: int = CURRENT_FORMAT_VERSION


# ---------------------------------------------------------------------------
# Serialisation
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var blocks_out: Array = []
	for block in placed_blocks:
		if block is Dictionary:
			blocks_out.append(block.duplicate(true))

	return {
		"format_version": format_version,
		"player_position": [player_position.x, player_position.y, player_position.z],
		"player_health_current": player_health_current,
		"player_health_max": player_health_max,
		"inventory_items": inventory_items.duplicate(true),
		"placed_blocks": blocks_out,
		"score": score,
		"weapon_index": weapon_index,
		"xp_level": xp_level,
		"xp_current": xp_current,
		"wave_number": wave_number,
		"session_elapsed_sec": session_elapsed_sec,
		"world_id": world_id,
		"project_id": project_id,
		"profile_id": profile_id,
		"saved_at_iso": saved_at_iso,
	}


static func from_dict(d: Dictionary) -> SandboxSnapshot:
	if typeof(d) != TYPE_DICTIONARY:
		return null

	var snap := SandboxSnapshot.new()

	# --- format version ---
	snap.format_version = int(d.get("format_version", CURRENT_FORMAT_VERSION))

	# --- player position ---
	var pos_raw: Variant = d.get("player_position", [])
	if pos_raw is Array and pos_raw.size() >= 3:
		snap.player_position = Vector3(
			float(pos_raw[0]),
			float(pos_raw[1]),
			float(pos_raw[2])
		)

	# --- health ---
	snap.player_health_current = int(d.get("player_health_current", 100))
	snap.player_health_max = int(d.get("player_health_max", 100))

	# --- inventory ---
	var inv_raw: Variant = d.get("inventory_items", {})
	if inv_raw is Dictionary:
		for key in inv_raw.keys():
			snap.inventory_items[String(key)] = int(inv_raw[key])

	# --- placed blocks ---
	var blocks_raw: Variant = d.get("placed_blocks", [])
	if blocks_raw is Array:
		for entry in blocks_raw:
			if entry is Dictionary and entry.has("cell") and entry.has("kind_id"):
				var cell_raw: Variant = entry.get("cell", [])
				if cell_raw is Array and cell_raw.size() >= 3:
					snap.placed_blocks.append({
						"cell": [float(cell_raw[0]), float(cell_raw[1]), float(cell_raw[2])],
						"kind_id": String(entry["kind_id"]),
					})

	# --- progression ---
	snap.score = int(d.get("score", 0))
	snap.weapon_index = int(d.get("weapon_index", 0))
	snap.xp_level = int(d.get("xp_level", 1))
	snap.xp_current = int(d.get("xp_current", 0))
	snap.wave_number = int(d.get("wave_number", 0))

	# --- session ---
	snap.session_elapsed_sec = float(d.get("session_elapsed_sec", 0.0))

	# --- identity ---
	snap.world_id = String(d.get("world_id", ""))
	snap.project_id = String(d.get("project_id", ""))
	snap.profile_id = String(d.get("profile_id", ""))

	# --- metadata ---
	snap.saved_at_iso = String(d.get("saved_at_iso", ""))

	return snap


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

## A snapshot is valid when it can be meaningfully restored.
## At minimum, world_id and project_id must be non-empty.
func is_valid() -> bool:
	if world_id.strip_edges().is_empty():
		return false
	if project_id.strip_edges().is_empty():
		return false
	return true

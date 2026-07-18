## Domain value object capturing everything needed to resume a kid's
## sandbox: which world template, where the player is, what they're
## carrying, what they've placed/broken, and the broader progression
## snapshot (collectibles, achievements, unlocks, quest progress).
##
## Persisted as JSON under user:// so a relaunch resumes the latest valid
## save by default. Corrupt or incomplete files fall back to a fresh
## empty state — never a hard crash.
class_name SandboxState
extends RefCounted

var world_id: String = ""
var player_position: Vector3 = Vector3.ZERO
var inventory: Dictionary = {}            ## item_id -> count
var placed_blocks: Array = []             ## Array[Dictionary] {cell: Vector3i, kind: String}
var progression: ProgressState = ProgressState.new()
var saved_at_unix: int = 0


func _init() -> void:
	inventory = {}
	placed_blocks = []
	progression = ProgressState.new()
	saved_at_unix = 0


func to_dict() -> Dictionary:
	var blocks: Array = []
	for entry in placed_blocks:
		if entry is Dictionary:
			var cell: Variant = entry.get("cell", null)
			var kind: String = String(entry.get("kind", ""))
			if cell is Vector3i:
				blocks.append({
					"x": (cell as Vector3i).x,
					"y": (cell as Vector3i).y,
					"z": (cell as Vector3i).z,
					"kind": kind,
				})
	var prog: Dictionary = {
		"collectibles": progression.collectibles,
		"achievements": Array(progression.achievements),
		"unlocks": Array(progression.unlocks),
		"quest_progress": progression.quest_progress,
		"score": progression.score,
	}
	return {
		"schema": 1,
		"world_id": world_id,
		"player_position": {"x": player_position.x, "y": player_position.y, "z": player_position.z},
		"inventory": inventory,
		"placed_blocks": blocks,
		"progression": prog,
		"saved_at_unix": saved_at_unix,
	}


static func from_dict(d: Dictionary) -> SandboxState:
	var s: SandboxState = SandboxState.new()
	s.world_id = String(d.get("world_id", ""))
	var pos: Variant = d.get("player_position", null)
	if pos is Dictionary:
		s.player_position = Vector3(
			float(pos.get("x", 0.0)),
			float(pos.get("y", 0.0)),
			float(pos.get("z", 0.0)),
		)
	var inv: Variant = d.get("inventory", null)
	if inv is Dictionary:
		s.inventory = (inv as Dictionary).duplicate(true)
	var blocks: Variant = d.get("placed_blocks", null)
	if blocks is Array:
		for entry in (blocks as Array):
			if entry is Dictionary and entry.has("kind") and entry.has("x") and entry.has("y") and entry.has("z"):
				s.placed_blocks.append({
					"cell": Vector3i(int(entry["x"]), int(entry["y"]), int(entry["z"])),
					"kind": String(entry["kind"]),
				})
	var prog: Variant = d.get("progression", null)
	if prog is Dictionary:
		var p: ProgressState = s.progression  # disambiguate from outer `s`
		var collectibles: Variant = prog.get("collectibles", null)
		if collectibles is Dictionary:
			p.collectibles = (collectibles as Dictionary).duplicate(true)
		var achievements: Variant = prog.get("achievements", null)
		if achievements is Array:
			p.achievements = []
			for a in (achievements as Array):
				p.achievements.append(String(a))
		var unlocks: Variant = prog.get("unlocks", null)
		if unlocks is Array:
			p.unlocks = []
			for u in (unlocks as Array):
				p.unlocks.append(String(u))
		var quest_progress: Variant = prog.get("quest_progress", null)
		if quest_progress is Dictionary:
			p.quest_progress = (quest_progress as Dictionary).duplicate(true)
		p.score = int(prog.get("score", 0))
	s.saved_at_unix = int(d.get("saved_at_unix", 0))
	return s


func is_empty() -> bool:
	return (
		world_id.is_empty()
		and player_position == Vector3.ZERO
		and inventory.is_empty()
		and placed_blocks.is_empty()
		and progression.achievements.is_empty()
		and progression.unlocks.is_empty()
		and progression.quest_progress.is_empty()
		and progression.score == 0
	)

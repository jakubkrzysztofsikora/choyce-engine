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

static var PERSIST_PATH: String = "user://sandbox_state.json"

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


static func _effective_path(path: String) -> String:
	return PERSIST_PATH if path.strip_edges().is_empty() else path


static func _ensure_parent_dir(path: String) -> bool:
	var dir_path := path.get_base_dir()
	if dir_path.is_empty():
		return true
	var absolute_dir := ProjectSettings.globalize_path(dir_path)
	if DirAccess.dir_exists_absolute(absolute_dir):
		return true
	return DirAccess.make_dir_recursive_absolute(absolute_dir) == OK


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


static func load_from_disk(path: String = "") -> SandboxState:
	var resolved_path := _effective_path(path)
	if not FileAccess.file_exists(resolved_path):
		return SandboxState.new()
	var file := FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		return SandboxState.new()
	var raw := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(raw) != OK:
		return SandboxState.new()
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return SandboxState.new()
	var s := from_dict(parsed as Dictionary)
	if s.is_empty():
		return SandboxState.new()
	return s


func save_to_disk(path: String = "") -> bool:
	if world_id.is_empty():
		return false
	if saved_at_unix == 0:
		saved_at_unix = int(Time.get_unix_time_from_system())
	var resolved_path := _effective_path(path)
	if not _ensure_parent_dir(resolved_path):
		return false
	var file := FileAccess.open(resolved_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(), "  "))
	file.close()
	return true


static func clear_disk(path: String = "") -> bool:
	var resolved_path := _effective_path(path)
	if not FileAccess.file_exists(resolved_path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(resolved_path)) == OK


static func disk_exists(path: String = "") -> bool:
	return FileAccess.file_exists(_effective_path(path))

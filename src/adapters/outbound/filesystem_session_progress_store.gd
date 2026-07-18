## FilesystemSessionProgressStore - VS-026
## Persistent filesystem-based adapter for SessionProgressStorePort.
## Saves and loads player progression state to/from the user filesystem.
##
## Uses Godot's user:// path for cross-platform persistence.
## Files are organized as: user://saves/{profile_id}/{world_id}.json
##
## Implements the SessionProgressStorePort contract for Phase 2 persistence.

class_name FilesystemSessionProgressStore
extends SessionProgressStorePort

## Root directory for all saves
const SAVE_ROOT := "user://saves/"


## Initialize the store (for method chaining)
func setup() -> FilesystemSessionProgressStore:
	return self


## Save progression state for a player+world combination
func save_progress(profile_id: String, world_id: String, progress: ProgressState) -> bool:
	if profile_id.strip_edges().is_empty() or world_id.strip_edges().is_empty() or progress == null:
		push_error("FilesystemSessionProgressStore: Invalid parameters for save_progress")
		return false
	
	var path := _get_save_path(profile_id, world_id)
	var dir_path := path.get_base_dir()
	
	# Create directory if it doesn't exist
	DirAccess.make_dir_recursive_absolute(dir_path)
	
	# Save to file
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("FilesystemSessionProgressStore: Failed to open file %s for writing" % path)
		return false
	
	# Build JSON manually since Godot's JSON.stringify doesn't handle all types well
	var json_str = _serialize_progress_state(progress)
	file.store_string(json_str)
	file.close()
	return true


## Load progression state for a player+world combination
func load_progress(profile_id: String, world_id: String) -> ProgressState:
	if profile_id.strip_edges().is_empty() or world_id.strip_edges().is_empty():
		push_error("FilesystemSessionProgressStore: Invalid parameters for load_progress")
		return ProgressState.new()
	
	var path := _get_save_path(profile_id, world_id)
	
	if not FileAccess.file_exists(path):
		# No save file exists, return empty progress
		return ProgressState.new()
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("FilesystemSessionProgressStore: Failed to open file %s for reading" % path)
		return ProgressState.new()
	
	var json = JSON.new()
	var parse_err = json.parse(file.get_as_text())
	file.close()
	
	if parse_err != OK:
		push_error("FilesystemSessionProgressStore: Failed to parse JSON from %s" % path)
		return ProgressState.new()
	
	return _deserialize_progress_state(json.get_data())


## Clear progression for a world
func clear_progress(profile_id: String, world_id: String) -> bool:
	if profile_id.strip_edges().is_empty() or world_id.strip_edges().is_empty():
		push_error("FilesystemSessionProgressStore: Invalid parameters for clear_progress")
		return false
	
	var path := _get_save_path(profile_id, world_id)
	
	if not FileAccess.file_exists(path):
		# File doesn't exist, nothing to clear
		return false
	
	var err = DirAccess.remove_absolute(path)
	if err != OK:
		push_error("FilesystemSessionProgressStore: Failed to delete %s" % path)
		return false
	
	return true


## Get all progression records for a player
func list_player_progress(profile_id: String) -> Array:
	var results: Array = []
	
	if profile_id.strip_edges().is_empty():
		push_error("FilesystemSessionProgressStore: Invalid profile_id for list_player_progress")
		return results
	
	var profile_dir := _get_profile_dir(profile_id)
	
	var dir = DirAccess.open(profile_dir)
	if dir == null:
		# Profile directory doesn't exist, no saves
		return results
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.get_extension().to_lower() == "json":
			var world_id := file_name.get_basename()
			var progress = load_progress(profile_id, world_id)
			if progress != null:
				results.append({"world_id": world_id, "progress": progress})
	
		file_name = dir.get_next()
	dir.list_dir_end()
	return results


## Get the filesystem path for a save file
func _get_save_path(profile_id: String, world_id: String) -> String:
	# Sanitize profile_id and world_id to be filesystem-safe
	var safe_profile = _sanitize_filename(profile_id)
	var safe_world = _sanitize_filename(world_id)
	return "%s%s/%s.json" % [SAVE_ROOT, safe_profile, safe_world]


## Get the directory for a profile's saves
func _get_profile_dir(profile_id: String) -> String:
	var safe_profile = _sanitize_filename(profile_id)
	return "%s%s/" % [SAVE_ROOT, safe_profile]


## Sanitize a string to be filesystem-safe
func _sanitize_filename(name: String) -> String:
	# Replace problematic characters
	var sanitized = name
	sanitized = sanitized.replace("/", "_")
	sanitized = sanitized.replace("\\", "_")
	sanitized = sanitized.replace(":", "_")
	sanitized = sanitized.replace("*", "_")
	sanitized = sanitized.replace("?", "_")
	sanitized = sanitized.replace('"', "_")
	sanitized = sanitized.replace("<", "_")
	sanitized = sanitized.replace(">", "_")
	sanitized = sanitized.replace("|", "_")
	return sanitized.strip_edges()


## Serialize ProgressState to JSON string
func _serialize_progress_state(progress: ProgressState) -> String:
	var data = {}
	data["collectibles"] = progress.collectibles
	data["achievements"] = progress.achievements
	data["unlocks"] = progress.unlocks
	data["quest_progress"] = progress.quest_progress
	data["score"] = progress.score

	return JSON.stringify(data, "", false)


## Deserialize JSON data to ProgressState
func _deserialize_progress_state(data: Dictionary) -> ProgressState:
	var progress = ProgressState.new()
	
	if data.has("collectibles") and data["collectibles"] is Dictionary:
		progress.collectibles = data["collectibles"].duplicate(true)
	
	if data.has("achievements") and data["achievements"] is Array:
		progress.achievements = data["achievements"].duplicate(true)
	
	if data.has("unlocks") and data["unlocks"] is Array:
		progress.unlocks = data["unlocks"].duplicate(true)
	
	if data.has("quest_progress") and data["quest_progress"] is Dictionary:
		progress.quest_progress = data["quest_progress"].duplicate(true)
	
	if data.has("score"):
		progress.score = int(data["score"])
	
	return progress

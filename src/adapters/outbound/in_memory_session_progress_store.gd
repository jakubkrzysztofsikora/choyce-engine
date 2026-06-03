## In-memory adapter for SessionProgressStorePort.
## Keyed by (profile_id, world_id). Used for the default Phase 1 build until a
## persistent FilesystemSessionProgressStore is added.
class_name InMemorySessionProgressStore
extends SessionProgressStorePort

var _by_key: Dictionary = {}
var _by_profile: Dictionary = {}


func setup() -> InMemorySessionProgressStore:
	_by_key = {}
	_by_profile = {}
	return self


func save_progress(profile_id: String, world_id: String, progress: ProgressState) -> bool:
	if profile_id.strip_edges().is_empty() or world_id.strip_edges().is_empty() or progress == null:
		return false
	var key := _key(profile_id, world_id)
	_by_key[key] = progress
	var per_profile: Array = _by_profile.get(profile_id, [])
	if not per_profile.has(world_id):
		per_profile.append(world_id)
		_by_profile[profile_id] = per_profile
	return true


func load_progress(profile_id: String, world_id: String) -> ProgressState:
	var key := _key(profile_id, world_id)
	var variant: Variant = _by_key.get(key, null)
	if variant is ProgressState:
		return variant as ProgressState
	return ProgressState.new()


func clear_progress(profile_id: String, world_id: String) -> bool:
	var key := _key(profile_id, world_id)
	if not _by_key.has(key):
		return false
	_by_key.erase(key)
	var per_profile: Array = _by_profile.get(profile_id, [])
	per_profile.erase(world_id)
	if per_profile.is_empty():
		_by_profile.erase(profile_id)
	else:
		_by_profile[profile_id] = per_profile
	return true


func list_player_progress(profile_id: String) -> Array:
	var results: Array = []
	var world_ids: Array = _by_profile.get(profile_id, [])
	for world_id in world_ids:
		var key := _key(profile_id, String(world_id))
		var variant: Variant = _by_key.get(key, null)
		if variant is ProgressState:
			results.append({"world_id": world_id, "progress": variant})
	return results


func _key(profile_id: String, world_id: String) -> String:
	return "%s::%s" % [profile_id, world_id]

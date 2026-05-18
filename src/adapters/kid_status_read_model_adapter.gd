## In-memory adapter for KidStatusReadModel.
## Maintains kid-facing project summaries and progression views.
class_name KidStatusReadModelAdapter
extends KidStatusReadModel

const ADTECH_TOKENS: Array[String] = [
	"advertising",
	"ad_id",
	"adid",
	"idfa",
	"gaid",
	"idfv",
	"adtech",
]

var _projects: Dictionary = {}  # {project_id: {title, progress_pct, last_played, session_count, profile_id}}


func get_project_status(project_id: String, profile_id: String) -> Dictionary:
	if project_id not in _projects:
		return {}

	var data: Dictionary = _projects[project_id]
	var owner_profile_id := str(data.get("profile_id", "")).strip_edges()
	if not owner_profile_id.is_empty() and owner_profile_id != profile_id:
		return {}

	return _sanitize_dictionary({
		"project_id": project_id,
		"profile_id": owner_profile_id if not owner_profile_id.is_empty() else profile_id,
		"title": data.get("title", ""),
		"progress_pct": data.get("progress_pct", 0),
		"last_played": data.get("last_played", ""),
		"session_count": data.get("session_count", 0),
		"collectibles_found": data.get("collectibles_found", 0),
		"achievements_earned": data.get("achievements_earned", 0),
	})


func list_recent_projects(profile_id: String, limit: int = 20) -> Array:
	var result: Array = []
	var sorted_projects: Array = []
	for project_variant in _projects.values():
		if not (project_variant is Dictionary):
			continue
		var project_data: Dictionary = project_variant
		var owner_profile_id := str(project_data.get("profile_id", "")).strip_edges()
		if not owner_profile_id.is_empty() and owner_profile_id != profile_id:
			continue
		sorted_projects.append(project_data)

	sorted_projects.sort_custom(func(a, b): return a.get("last_played", "") > b.get("last_played", ""))

	for i in range(min(limit, sorted_projects.size())):
		result.append(_sanitize_dictionary({
			"project_id": sorted_projects[i].get("project_id", ""),
			"title": sorted_projects[i].get("title", ""),
			"progress_pct": sorted_projects[i].get("progress_pct", 0),
			"last_played": sorted_projects[i].get("last_played", ""),
		}))

	return result


func update_from_event(event: DomainEvent) -> void:
	if event == null:
		return

	var event_type := str(event.event_type)
	var project_id := _event_string(event, "project_id")
	if project_id.is_empty():
		project_id = _event_string(event, "world_id")
	if project_id.is_empty():
		return
	var event_profile_id := _event_profile_id(event)

	if event_type == "WorldEdited":
		if project_id not in _projects:
			_projects[project_id] = {
				"project_id": project_id,
				"title": _event_string(event, "title") if _event_string(event, "title") != "" else _event_string(event, "world_id"),
				"progress_pct": 0,
				"last_played": "",
				"session_count": 0,
				"collectibles_found": 0,
				"achievements_earned": 0,
				"profile_id": event_profile_id,
			}
	elif event_type == "SessionProgressUpdatedEvent":
		if project_id not in _projects:
			_projects[project_id] = {
				"project_id": project_id,
				"title": project_id,
				"progress_pct": 0,
				"last_played": "",
				"session_count": 0,
				"collectibles_found": 0,
				"achievements_earned": 0,
				"profile_id": event_profile_id,
			}
		if str(_projects[project_id].get("profile_id", "")).is_empty() and not event_profile_id.is_empty():
			_projects[project_id]["profile_id"] = event_profile_id
		_projects[project_id]["last_played"] = str(event.timestamp)
		_projects[project_id]["session_count"] += 1
		var progress = event.get("progress")
		if progress is ProgressState:
			var ps: ProgressState = progress
			_projects[project_id]["progress_pct"] = _compute_progress_pct(ps)
			_projects[project_id]["collectibles_found"] = _count_collectibles(ps)
			_projects[project_id]["achievements_earned"] = ps.achievements.size()
		else:
			var new_progress := _event_int(event, "progress_pct")
			if new_progress > 0:
				_projects[project_id]["progress_pct"] = new_progress
			if event.get("collectibles_found") != null:
				_projects[project_id]["collectibles_found"] += _event_int(event, "collectibles_found")
			if event.get("achievements_earned") != null:
				_projects[project_id]["achievements_earned"] += _event_int(event, "achievements_earned")


func _event_string(event: Object, field_name: String) -> String:
	var value: Variant = event.get(field_name)
	if value == null:
		return ""
	return str(value)


func _event_int(event: Object, field_name: String) -> int:
	var value: Variant = event.get(field_name)
	return int(value)


func _event_profile_id(event: Object) -> String:
	var profile_id := _event_string(event, "profile_id").strip_edges()
	if not profile_id.is_empty():
		return profile_id
	var actor_id := _event_string(event, "actor_id").strip_edges()
	if not actor_id.is_empty():
		return actor_id
	return _event_string(event, "child_id").strip_edges()


func _sanitize_dictionary(input: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for key_variant in input.keys():
		var key := str(key_variant)
		if _is_adtech_key(key):
			continue
		output[key] = _sanitize_value(input[key_variant])
	return output


func _sanitize_value(value: Variant) -> Variant:
	if value is Dictionary:
		return _sanitize_dictionary(value)
	if value is Array:
		var arr: Array = value
		var output: Array = []
		for item in arr:
			output.append(_sanitize_value(item))
		return output
	return value


func _compute_progress_pct(progress: ProgressState) -> int:
	if progress == null:
		return 0
	var total := progress.achievements.size() + progress.unlocks.size() + progress.quest_progress.size()
	var completed := progress.achievements.size() + progress.unlocks.size()
	for quest_id in progress.quest_progress.keys():
		if progress.is_quest_complete(quest_id, 3):
			completed += 1
	if total <= 0:
		return 0
	return int(clampi(completed * 100 / total, 0, 100))


func _count_collectibles(progress: ProgressState) -> int:
	if progress == null:
		return 0
	var total := 0
	for count in progress.collectibles.values():
		total += int(count)
	return total


func _is_adtech_key(key: String) -> bool:
	var normalized := key.strip_edges().to_lower()
	for token in ADTECH_TOKENS:
		if normalized.find(token) >= 0:
			return true
	return false

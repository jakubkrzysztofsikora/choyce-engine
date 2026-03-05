## In-memory adapter for KidStatusReadModel.
## Maintains kid-facing project summaries and progression views.
class_name KidStatusReadModelAdapter
extends KidStatusReadModel


var _projects: Dictionary = {}  # {project_id: {title, progress_pct, last_played, session_count}}


func get_project_status(project_id: String, profile_id: String) -> Dictionary:
	if project_id not in _projects:
		return {}

	var data = _projects[project_id]
	return {
		"project_id": project_id,
		"profile_id": profile_id,
		"title": data.get("title", ""),
		"progress_pct": data.get("progress_pct", 0),
		"last_played": data.get("last_played", ""),
		"session_count": data.get("session_count", 0),
		"collectibles_found": data.get("collectibles_found", 0),
		"achievements_earned": data.get("achievements_earned", 0),
	}


func list_recent_projects(profile_id: String, limit: int = 20) -> Array:
	var result = []
	var sorted_projects = _projects.values()
	sorted_projects.sort_custom(func(a, b): return a.get("last_played", "") > b.get("last_played", ""))

	for i in range(min(limit, sorted_projects.size())):
		result.append({
			"project_id": sorted_projects[i].get("project_id", ""),
			"title": sorted_projects[i].get("title", ""),
			"progress_pct": sorted_projects[i].get("progress_pct", 0),
			"last_played": sorted_projects[i].get("last_played", ""),
		})

	return result


func update_from_event(event: DomainEvent) -> void:
	if event == null:
		return

	var event_type := str(event.event_type)
	var project_id := _event_string(event, "project_id")
	if project_id.is_empty():
		return

	if event_type == "ProjectCreatedEvent":
		_projects[project_id] = {
			"project_id": project_id,
			"title": _event_string(event, "title"),
			"progress_pct": 0,
			"last_played": "",
			"session_count": 0,
			"collectibles_found": 0,
			"achievements_earned": 0,
		}
	elif event_type == "SessionCompletedEvent":
		if project_id in _projects:
			_projects[project_id]["last_played"] = str(event.timestamp)
			_projects[project_id]["session_count"] += 1
			_projects[project_id]["progress_pct"] = _event_int(event, "progress_pct")
	elif event_type == "CollectibleFoundEvent":
		if project_id in _projects:
			_projects[project_id]["collectibles_found"] += 1
	elif event_type == "AchievementUnlockedEvent":
		if project_id in _projects:
			_projects[project_id]["achievements_earned"] += 1


func _event_string(event: Object, field_name: String) -> String:
	var value: Variant = event.get(field_name)
	if value == null:
		return ""
	return str(value)


func _event_int(event: Object, field_name: String) -> int:
	var value: Variant = event.get(field_name)
	return int(value)

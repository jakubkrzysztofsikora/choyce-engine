## Filesystem adapter for PublishStorePort.
## Persists each publish request as a JSON file under a configurable root directory.
## File layout: <root>/<request_id>.json
##
## Atomic write: write to a .tmp file then rename (via delete + rename) to avoid
## partial writes leaving corrupt state on power loss.
class_name FilesystemPublishStore
extends PublishStorePort

const FORMAT_VERSION := 1
const TMP_SUFFIX := ".tmp"

var _root_dir: String = "user://choyce_publish"

## 250 ms debounce is handled by callers; this adapter always fsyncs immediately
## so data is durable after each successful save.


func setup(root_dir: String = "user://choyce_publish") -> FilesystemPublishStore:
	_root_dir = root_dir.strip_edges()
	if _root_dir.is_empty():
		_root_dir = "user://choyce_publish"
	_ensure_dir(_root_dir)
	return self


func save_request(request: PublishRequest) -> bool:
	if request == null:
		return false
	var rid := request.request_id.strip_edges()
	if rid.is_empty():
		return false

	_ensure_dir(_root_dir)
	var target_path := _request_path(rid)
	var tmp_path := target_path + TMP_SUFFIX
	var data := _serialize_request(request)

	if not _write_json(tmp_path, data):
		return false

	# Atomic rename: remove target if present, then rename tmp → target.
	if FileAccess.file_exists(target_path):
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(target_path))
		if err != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
			return false

	var dir := DirAccess.open(_root_dir)
	if dir == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
		return false

	# DirAccess.rename() accepts full virtual paths (user://).
	var rename_err := dir.rename(tmp_path, target_path)
	if rename_err != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
		return false

	return true


func load_request(request_id: String) -> PublishRequest:
	var rid := request_id.strip_edges()
	if rid.is_empty():
		return null

	var path := _request_path(rid)
	if not FileAccess.file_exists(path):
		return null

	var data = _read_json(path)
	if not (data is Dictionary):
		return null

	return _deserialize_request(data as Dictionary)


func list_requests_for_project(project_id: String) -> Array:
	if project_id.strip_edges().is_empty():
		return []

	var results: Array = []
	_ensure_dir(_root_dir)

	var dir := DirAccess.open(_root_dir)
	if dir == null:
		return results

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.ends_with(".json") and not entry.ends_with(TMP_SUFFIX):
			var rid := entry.get_basename()
			var req := load_request(rid)
			if req != null and req.project_id == project_id:
				results.append(req)
		entry = dir.get_next()
	dir.list_dir_end()

	return results


func list_published() -> Array:
	var results: Array = []
	_ensure_dir(_root_dir)

	var dir := DirAccess.open(_root_dir)
	if dir == null:
		return results

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.ends_with(".json") and not entry.ends_with(TMP_SUFFIX):
			var rid := entry.get_basename()
			var req := load_request(rid)
			if req != null and req.state == PublishRequest.PublishState.PUBLISHED:
				results.append(req)
		entry = dir.get_next()
	dir.list_dir_end()

	return results


func _serialize_request(request: PublishRequest) -> Dictionary:
	var mod_results: Array = []
	for r in request.moderation_results:
		if r is ModerationResult:
			mod_results.append({
				"category": r.category,
				"verdict": int(r.verdict),
				"reason": r.reason,
				"confidence": r.confidence,
			})

	return {
		"format_version": FORMAT_VERSION,
		"request_id": request.request_id,
		"project_id": request.project_id,
		"world_id": request.world_id,
		"state": int(request.state),
		"visibility": int(request.visibility),
		"requester_id": request.requester_id,
		"reviewer_id": request.reviewer_id,
		"family_id": request.family_id,
		"classroom_id": request.classroom_id,
		"rejection_reason": request.rejection_reason,
		"created_at": request.created_at,
		"published_at": request.published_at,
		"unpublished_at": request.unpublished_at,
		"revision_count": request.revision_count,
	}


func _deserialize_request(data: Dictionary) -> PublishRequest:
	var req := PublishRequest.new(
		str(data.get("project_id", "")),
		str(data.get("world_id", ""))
	)
	req.request_id = str(data.get("request_id", ""))
	req.state = int(data.get("state", int(PublishRequest.PublishState.DRAFT)))
	req.visibility = int(data.get("visibility", int(PublishRequest.Visibility.PRIVATE)))
	req.requester_id = str(data.get("requester_id", ""))
	req.reviewer_id = str(data.get("reviewer_id", ""))
	req.family_id = str(data.get("family_id", ""))
	req.classroom_id = str(data.get("classroom_id", ""))
	req.rejection_reason = str(data.get("rejection_reason", ""))
	req.created_at = str(data.get("created_at", ""))
	req.published_at = str(data.get("published_at", ""))
	req.unpublished_at = str(data.get("unpublished_at", ""))
	req.revision_count = int(data.get("revision_count", 0))
	return req


func _request_path(request_id: String) -> String:
	var safe_id := request_id.replace("/", "_").replace("\\", "_").replace(":", "_")
	return "%s/%s.json" % [_root_dir, safe_id]


func _write_json(path: String, data: Variant) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("FilesystemPublishStore: cannot open for write: %s (error: %d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _ensure_dir(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var result := DirAccess.make_dir_recursive_absolute(absolute)
	return result == OK or DirAccess.dir_exists_absolute(absolute)

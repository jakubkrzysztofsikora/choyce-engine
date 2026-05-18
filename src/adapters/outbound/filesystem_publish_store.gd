## Filesystem adapter for PublishStorePort.
## Persists each publish request as a JSON file under a configurable root directory.
## File layout: <root>/<request_id>.json
##
## Atomic write: write to a .tmp file then rename (via delete + rename) to avoid
## partial writes leaving corrupt state on power loss.
##
## Writes debounced with 250ms trailing-edge timer; call flush() on shutdown.
## In-memory cache is the source of truth for reads; disk is updated lazily.
##
## Integration:
##   - Call flush_if_due(delta_ms) each frame from the main loop to drive the
##     debounce window (e.g. pass Engine.get_process_frames() delta in ms).
##   - Call flush() before shutdown / _exit_tree() to ensure durability.
class_name FilesystemPublishStore
extends PublishStorePort

const FORMAT_VERSION := 1
const TMP_SUFFIX := ".tmp"
const DEBOUNCE_MS := 250

var _root_dir: String = "user://choyce_publish"

## In-memory cache: request_id (String) → PublishRequest
var _cache: Dictionary = {}
## True when _cache has unsaved changes.
var _dirty: bool = false
## Accumulated milliseconds since the last write call (for debounce tracking).
var _pending_msec: int = 0


func setup(root_dir: String = "user://choyce_publish") -> FilesystemPublishStore:
	_root_dir = root_dir.strip_edges()
	if _root_dir.is_empty():
		_root_dir = "user://choyce_publish"
	_ensure_dir(_root_dir)
	_load_all()
	return self


## Write a publish request to the in-memory cache immediately.
## Marks the store dirty and resets the debounce window.
## Returns false for invalid input; true otherwise.
func save_request(request: PublishRequest) -> bool:
	if request == null:
		return false
	var rid := request.request_id.strip_edges()
	if rid.is_empty():
		return false

	_cache[rid] = request
	_mark_dirty()
	return true


## Read a publish request. Returns from in-memory cache; never reads disk.
func load_request(request_id: String) -> PublishRequest:
	var rid := request_id.strip_edges()
	if rid.is_empty():
		return null
	return _cache.get(rid, null)


## Return all requests whose state == PUBLISHED.
## Reads from in-memory cache only.
func list_published() -> Array:
	var results: Array = []
	for req in _cache.values():
		if req is PublishRequest and req.state == PublishRequest.PublishState.PUBLISHED:
			results.append(req)
	return results


## Return all requests matching project_id.
## Reads from in-memory cache only.
func list_requests_for_project(project_id: String) -> Array:
	if project_id.strip_edges().is_empty():
		return []
	var results: Array = []
	for req in _cache.values():
		if req is PublishRequest and req.project_id == project_id:
			results.append(req)
	return results


## Drive the debounce timer. Pass the milliseconds elapsed since the last call
## (e.g. from _process delta converted to ms, or from a fixed-tick loop).
## Flushes to disk when accumulated time >= DEBOUNCE_MS and the store is dirty.
##
## Example (main.gd _process):
##   _publish_store.flush_if_due(delta * 1000.0)
func flush_if_due(elapsed_msec: int) -> void:
	if not _dirty:
		_pending_msec = 0
		return
	_pending_msec += elapsed_msec
	if _pending_msec >= DEBOUNCE_MS:
		_flush_to_disk()


## Flush all dirty in-memory state to disk immediately, regardless of timer.
## Call this before shutdown or whenever durability is required immediately.
func flush() -> void:
	if _dirty:
		_flush_to_disk()


# ── Private ─────────────────────────────────────────────────────────────────────

func _mark_dirty() -> void:
	_dirty = true
	_pending_msec = 0


## Load all existing request files from disk into _cache on startup.
func _load_all() -> void:
	_cache = {}
	_ensure_dir(_root_dir)
	var dir := DirAccess.open(_root_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.ends_with(".json") and not entry.ends_with(TMP_SUFFIX):
			var rid := entry.get_basename()
			var path := _request_path(rid)
			var data = _read_json(path)
			if data is Dictionary:
				var req := _deserialize_request(data as Dictionary)
				if req != null:
					_cache[rid] = req
		entry = dir.get_next()
	dir.list_dir_end()


## Write every cached request to disk atomically.
func _flush_to_disk() -> void:
	_ensure_dir(_root_dir)
	for rid in _cache.keys():
		var req := _cache[rid] as PublishRequest
		if req == null:
			continue
		var target_path := _request_path(rid)
		var tmp_path := target_path + TMP_SUFFIX
		var data := _serialize_request(req)

		if not _write_json(tmp_path, data):
			continue

		# Atomic rename: remove target if present, then rename tmp → target.
		if FileAccess.file_exists(target_path):
			var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(target_path))
			if err != OK:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
				continue

		var dir := DirAccess.open(_root_dir)
		if dir == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
			continue

		var rename_err := dir.rename(tmp_path, target_path)
		if rename_err != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))

	_dirty = false
	_pending_msec = 0


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

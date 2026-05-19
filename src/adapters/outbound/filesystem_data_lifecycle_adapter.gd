## Filesystem adapter for DataLifecyclePort.
## Implements COPPA-compliant export and deletion of kid profile data.
##
## export_kid_data  — collects projects, consents, audit records into a single
##                    JSON file at user://choyce_export/<profile_id>_<unix_ts>.json
## delete_kid_data  — removes profile's project files, clears consent record,
##                    and appends a tombstone to the audit ledger (ledger preserved).
## update_retention / get_job / enqueue_* — not applicable in local-only mode;
##                    delegate stubs return sensible defaults.
class_name FilesystemDataLifecycleAdapter
extends DataLifecyclePort

const EXPORT_DIR := "user://choyce_export"

var _project_store: FilesystemProjectStore
var _consent_store: FilesystemConsentStore
var _audit_ledger: AuditLedgerPort
var _clock: ClockPort


func setup(
	project_store: FilesystemProjectStore,
	consent_store: FilesystemConsentStore,
	audit_ledger: AuditLedgerPort,
	clock: ClockPort
) -> FilesystemDataLifecycleAdapter:
	_project_store = project_store
	_consent_store = consent_store
	_audit_ledger = audit_ledger
	_clock = clock
	return self


## Collect all data owned by profile_id and write a GDPR/COPPA export file.
## Returns {"ok": true, "path": "<path>", "size_bytes": N} on success.
## Returns {"ok": false, "error": "<reason>"} on failure.
func export_kid_data(profile_id: String) -> Dictionary:
	if profile_id.strip_edges().is_empty():
		return {"ok": false, "error": "profile_id required"}

	_ensure_dir(EXPORT_DIR)

	var unix_ts := _unix_ts()
	var export_path := "%s/%s_%s.json" % [EXPORT_DIR, profile_id, unix_ts]

	# Collect projects owned by this profile.
	var projects_data: Array = []
	if _project_store != null:
		for project in _project_store.list_projects():
			if project is Project and project.owner_profile_id == profile_id:
				projects_data.append({
					"project_id": project.project_id,
					"title": project.title,
					"description": project.description,
					"created_at": project.created_at,
					"updated_at": project.updated_at,
					"world_count": project.worlds.size(),
				})

	# Collect consent record for this profile.
	var consents_data: Dictionary = {}
	if _consent_store != null:
		var known_consent_types := ["cloud_sync", "ai_generation", "voice_input", "telemetry"]
		for ct in known_consent_types:
			consents_data[ct] = _consent_store.has_consent(profile_id, ct)

	# Collect audit records where actor_id == profile_id (bounded to 1000 entries).
	var audit_data: Array = []
	if _audit_ledger != null:
		var records: Array = _audit_ledger.get_records({"actor_id": profile_id, "limit": 1000})
		for rec in records:
			if rec is AuditRecord:
				audit_data.append({
					"record_id": rec.record_id,
					"event_type": rec.event_type,
					"actor_id": rec.actor_id,
					"timestamp": rec.timestamp,
					"payload": rec.payload.duplicate(),
				})

	var export_payload := {
		"profile_id": profile_id,
		"exported_at": _iso_now(),
		"projects": projects_data,
		"consents": consents_data,
		"audit": audit_data,
	}

	var json_text := JSON.stringify(export_payload, "\t")
	var file := FileAccess.open(export_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Cannot write export file: %s" % export_path}

	file.store_string(json_text)
	file.flush()
	file = null

	var size_bytes := json_text.length()

	return {"ok": true, "path": export_path, "size_bytes": size_bytes}


## Delete all data owned by profile_id.
## Appends a tombstone to the audit ledger; does NOT delete the ledger itself.
## Returns {"ok": true, "deleted_count": N} on success.
## Returns {"ok": false, "error": "<reason>"} on failure.
func delete_kid_data(profile_id: String) -> Dictionary:
	if profile_id.strip_edges().is_empty():
		return {"ok": false, "error": "profile_id required"}

	var deleted_count := 0

	# Delete project files owned by this profile.
	if _project_store != null:
		var projects := _project_store.list_projects()
		for project in projects:
			if not (project is Project):
				continue
			if project.owner_profile_id != profile_id:
				continue
			var project_dir := _project_dir_path(project.project_id)
			var removed := _remove_dir_recursive(project_dir)
			if removed:
				deleted_count += 1

	# Clear consent record for this profile by writing an empty consent block.
	if _consent_store != null:
		_clear_profile_consent(profile_id)

	# Append a tombstone audit record — the ledger itself is preserved.
	_append_tombstone(profile_id)

	return {"ok": true, "deleted_count": deleted_count}


## Stub: no cloud retention backend in local-only build.
func enqueue_export(payload: Dictionary) -> Dictionary:
	var profile_id := str(payload.get("subject_id", "")).strip_edges()
	return export_kid_data(profile_id)


## Stub: no cloud deletion backend in local-only build.
func enqueue_delete(payload: Dictionary) -> Dictionary:
	var profile_id := str(payload.get("subject_id", "")).strip_edges()
	return delete_kid_data(profile_id)


## Stub: no cloud retention backend.
func update_retention(_payload: Dictionary) -> bool:
	return true


## Stub: no cloud job tracking.
func get_job(_job_id: String) -> Dictionary:
	return {"ok": false, "error": "Job tracking unavailable in local-only build"}


# ── Private ────────────────────────────────────────────────────────────────────

func _clear_profile_consent(profile_id: String) -> void:
	# COPPA §312.5(c): consent must be erasable on parental request.
	# Uses the public delete_profile() API which marks dirty and forces a
	# durable disk flush. Prior implementation reached into the private
	# _profiles dict and duck-typed a non-existent _save() method, so the
	# deletion never reached disk and reloaded stale on next boot.
	if _consent_store == null:
		return
	if _consent_store.has_method("delete_profile"):
		_consent_store.delete_profile(profile_id)


func _append_tombstone(profile_id: String) -> void:
	if _audit_ledger == null:
		return
	var ts := _iso_now()
	var suffix := str(_unix_ts())
	var record_id := "lifecycle_data_deleted_%s_%s" % [profile_id, suffix]
	var payload := {
		"subject_profile_id": profile_id,
		"detail": "COPPA/GDPR-K data deletion completed",
		"deleted_by": "FilesystemDataLifecycleAdapter",
	}
	var record := AuditRecord.new(
		record_id,
		"DATA_DELETED",
		record_id,
		profile_id,
		ts,
		payload,
		_audit_ledger.last_hash()
	)
	_audit_ledger.append_record(record)


func _project_dir_path(project_id: String) -> String:
	# Mirror FilesystemProjectStore's _project_dir() convention.
	return "user://projects/%s" % project_id


func _remove_dir_recursive(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return false
	var dir := DirAccess.open(path)
	if dir == null:
		return false
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := "%s/%s" % [path, entry]
			var child_absolute := ProjectSettings.globalize_path(child)
			if dir.current_is_dir():
				_remove_dir_recursive(child)
			else:
				DirAccess.remove_absolute(child_absolute)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute)
	return true


func _ensure_dir(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var result := DirAccess.make_dir_recursive_absolute(absolute)
	return result == OK or DirAccess.dir_exists_absolute(absolute)


func _iso_now() -> String:
	if _clock != null:
		return _clock.now_iso()
	return Time.get_datetime_string_from_system(true, false)


func _unix_ts() -> int:
	if _clock != null and _clock.has_method("now_msec"):
		return int(_clock.now_msec() / 1000)
	return int(Time.get_unix_time_from_system())

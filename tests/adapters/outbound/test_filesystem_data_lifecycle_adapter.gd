## Tests for FilesystemDataLifecycleAdapter.
##
## MUST-1  export_kid_data() writes a JSON file under user://choyce_export/
## MUST-2  export JSON contains profile_id, exported_at, projects, consents, audit keys
## MUST-3  export includes only projects owned by the requested profile_id
## MUST-4  delete_kid_data() removes project directories owned by the profile
## MUST-5  delete_kid_data() appends a DATA_DELETED tombstone to the audit ledger
## MUST-6  delete_kid_data() is idempotent (second call returns deleted_count 0)
## MUST-7  empty profile_id returns {"ok": false} for both export and delete
extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var checks := 0

	const TEST_PROJECTS_DIR := "user://test_dl_projects"
	const TEST_CONSENT_DIR := "user://test_dl_consent"
	const TEST_AUDIT_DIR := "user://test_dl_audit"
	const TEST_EXPORT_DIR := "user://choyce_export"

	_cleanup_dir(TEST_PROJECTS_DIR)
	_cleanup_dir(TEST_CONSENT_DIR)
	_cleanup_dir(TEST_AUDIT_DIR)
	_cleanup_dir(TEST_EXPORT_DIR)

	# Build collaborators.
	var project_store := FilesystemProjectStore.new().setup(TEST_PROJECTS_DIR)
	var consent_store := FilesystemConsentStore.new().setup(TEST_CONSENT_DIR)
	var audit_ledger := FilesystemAuditLedger.new().setup(TEST_AUDIT_DIR)
	var clock: ClockPort = null  # null clock is acceptable; adapter falls back to Time.*

	# Seed test data: two projects for kid_A and one for kid_B.
	var proj_a1 := Project.new("proj_a1", "Alpha One")
	proj_a1.owner_profile_id = "kid_A"
	project_store.save_project(proj_a1)

	var proj_a2 := Project.new("proj_a2", "Alpha Two")
	proj_a2.owner_profile_id = "kid_A"
	project_store.save_project(proj_a2)

	var proj_b1 := Project.new("proj_b1", "Beta One")
	proj_b1.owner_profile_id = "kid_B"
	project_store.save_project(proj_b1)

	# Seed consent for kid_A.
	consent_store.request_consent("kid_A", "cloud_sync")

	# Seed two audit records: one for kid_A, one for kid_B.
	var rec_a := AuditRecord.new(
		"rec_kid_a_1", "WORLD_REMIXED", "rec_kid_a_1",
		"kid_A", Time.get_datetime_string_from_system(true, false),
		{}, audit_ledger.last_hash()
	)
	audit_ledger.append_record(rec_a)

	var rec_b := AuditRecord.new(
		"rec_kid_b_1", "WORLD_REMIXED", "rec_kid_b_1",
		"kid_B", Time.get_datetime_string_from_system(true, false),
		{}, audit_ledger.last_hash()
	)
	audit_ledger.append_record(rec_b)

	# Construct the adapter under test; override export dir constant via test helper.
	var adapter := FilesystemDataLifecycleAdapter.new().setup(
		project_store, consent_store, audit_ledger, clock
	)

	# ── MUST-1: export writes a file ──────────────────────────────────────────
	var export_result := adapter.export_kid_data("kid_A")
	checks += 1
	if not bool(export_result.get("ok", false)):
		failures.append("MUST-1: export_kid_data() must return ok=true. Got: %s" % str(export_result))

	checks += 1
	var export_path: String = str(export_result.get("path", ""))
	if not FileAccess.file_exists(export_path):
		failures.append("MUST-1b: export file must exist at reported path '%s'" % export_path)

	# ── MUST-2: exported JSON has correct top-level keys ─────────────────────
	var parsed_export: Variant = null
	if FileAccess.file_exists(export_path):
		var f := FileAccess.open(export_path, FileAccess.READ)
		if f != null:
			parsed_export = JSON.parse_string(f.get_as_text())

	checks += 1
	if not (parsed_export is Dictionary):
		failures.append("MUST-2: export file must contain valid JSON dictionary")
	else:
		var d: Dictionary = parsed_export as Dictionary
		for key in ["profile_id", "exported_at", "projects", "consents", "audit"]:
			checks += 1
			if not d.has(key):
				failures.append("MUST-2: export JSON missing key '%s'" % key)

		checks += 1
		if str(d.get("profile_id", "")) != "kid_A":
			failures.append("MUST-2: profile_id in export must be 'kid_A', got '%s'" % d.get("profile_id"))

	# ── MUST-3: export includes only kid_A's projects ─────────────────────────
	if parsed_export is Dictionary:
		var projects_arr = (parsed_export as Dictionary).get("projects", [])
		checks += 1
		if not (projects_arr is Array):
			failures.append("MUST-3: 'projects' must be an Array")
		else:
			var arr: Array = projects_arr as Array
			checks += 1
			if arr.size() != 2:
				failures.append("MUST-3: export must contain exactly 2 projects for kid_A, got %d" % arr.size())
			checks += 1
			var has_kid_b := false
			for p in arr:
				if p is Dictionary and str((p as Dictionary).get("project_id", "")) == "proj_b1":
					has_kid_b = true
			if has_kid_b:
				failures.append("MUST-3: export must NOT contain kid_B's project")

	# ── MUST-4: delete_kid_data() removes kid_A's project files ──────────────
	var delete_result := adapter.delete_kid_data("kid_A")
	checks += 1
	if not bool(delete_result.get("ok", false)):
		failures.append("MUST-4: delete_kid_data() must return ok=true. Got: %s" % str(delete_result))

	checks += 1
	if int(delete_result.get("deleted_count", -1)) != 2:
		failures.append("MUST-4b: deleted_count must be 2, got %d" % int(delete_result.get("deleted_count", -1)))

	# Verify project directories are gone.
	checks += 1
	var proj_a1_abs := ProjectSettings.globalize_path("%s/proj_a1" % TEST_PROJECTS_DIR)
	if DirAccess.dir_exists_absolute(proj_a1_abs):
		failures.append("MUST-4c: proj_a1 directory must be removed after delete")

	checks += 1
	var proj_a2_abs := ProjectSettings.globalize_path("%s/proj_a2" % TEST_PROJECTS_DIR)
	if DirAccess.dir_exists_absolute(proj_a2_abs):
		failures.append("MUST-4d: proj_a2 directory must be removed after delete")

	# kid_B's project must remain.
	checks += 1
	var proj_b1_abs := ProjectSettings.globalize_path("%s/proj_b1" % TEST_PROJECTS_DIR)
	if not DirAccess.dir_exists_absolute(proj_b1_abs):
		failures.append("MUST-4e: proj_b1 (kid_B) must NOT be removed by kid_A delete")

	# ── MUST-5: tombstone appended to audit ledger ────────────────────────────
	var audit_after := audit_ledger.get_records({"actor_id": "kid_A", "limit": 100})
	checks += 1
	var tombstone_found := false
	for rec in audit_after:
		if rec is AuditRecord and (rec as AuditRecord).event_type == "DATA_DELETED":
			tombstone_found = true
			break
	if not tombstone_found:
		failures.append("MUST-5: DATA_DELETED tombstone must be appended to audit ledger after delete")

	# kid_B's audit record must still be present (ledger not deleted).
	var audit_b := audit_ledger.get_records({"actor_id": "kid_B", "limit": 10})
	checks += 1
	if audit_b.size() == 0:
		failures.append("MUST-5b: audit ledger must still contain kid_B records after kid_A deletion")

	# ── MUST-6: idempotent delete ─────────────────────────────────────────────
	var delete_result2 := adapter.delete_kid_data("kid_A")
	checks += 1
	if not bool(delete_result2.get("ok", false)):
		failures.append("MUST-6: second delete must still return ok=true")

	checks += 1
	if int(delete_result2.get("deleted_count", -1)) != 0:
		failures.append("MUST-6b: second delete deleted_count must be 0, got %d" % int(delete_result2.get("deleted_count", -1)))

	# ── MUST-7: empty profile_id rejected ────────────────────────────────────
	var bad_export := adapter.export_kid_data("")
	checks += 1
	if bool(bad_export.get("ok", true)):
		failures.append("MUST-7a: export with empty profile_id must return ok=false")

	var bad_delete := adapter.delete_kid_data("")
	checks += 1
	if bool(bad_delete.get("ok", true)):
		failures.append("MUST-7b: delete with empty profile_id must return ok=false")

	# Cleanup.
	_cleanup_dir(TEST_PROJECTS_DIR)
	_cleanup_dir(TEST_CONSENT_DIR)
	_cleanup_dir(TEST_AUDIT_DIR)
	_cleanup_dir(TEST_EXPORT_DIR)

	if failures.is_empty():
		print("[PASS] FilesystemDataLifecycleAdapter (%d checks)" % checks)
		quit(0)
	else:
		print("[FAIL] FilesystemDataLifecycleAdapter")
		for item in failures:
			print("  - %s" % item)
		quit(1)


func _cleanup_dir(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	_remove_recursive(path)


func _remove_recursive(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := "%s/%s" % [path, entry]
			if dir.current_is_dir():
				_remove_recursive(child)
			else:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute)

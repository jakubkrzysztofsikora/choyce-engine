extends SceneTree

const SUITE_NAME := "PersistenceResilience"
const JOURNAL_FILE := "user://task058_persistence_resilience/journal.json"
const PROJECT_ROOT := "user://task058_persistence_resilience/projects"

class MockClock:
	extends ClockPort

	var _now_msec: int = 1000

	func set_now(value: int) -> void:
		_now_msec = value

	func advance(delta_msec: int) -> void:
		_now_msec += delta_msec

	func now_iso() -> String:
		return "2026-03-05T13:00:00Z"

	func now_msec() -> int:
		return _now_msec


class MockConsent:
	extends IdentityConsentPort

	var _grants: Dictionary = {}

	func grant(profile_id: String, consent_type: String) -> void:
		_grants["%s|%s" % [profile_id, consent_type]] = true

	func has_consent(profile_id: String, consent_type: String) -> bool:
		return _grants.has("%s|%s" % [profile_id, consent_type])

	func request_consent(profile_id: String, consent_type: String) -> bool:
		grant(profile_id, consent_type)
		return true


class MockCloudSync:
	extends RefCounted

	var synced_project_ids: Array[String] = []
	var available: bool = true

	func is_available() -> bool:
		return available

	func sync_project(project: Project) -> bool:
		if not available or project == null or project.project_id.strip_edges().is_empty():
			return false
		synced_project_ids.append(project.project_id)
		return true


var _checks_run: int = 0
var _failures: Array[String] = []


func _init() -> void:
	_cleanup_workspace()

	var scenarios: Array[Dictionary] = []
	scenarios.append(_run_autosave_cadence_scenario())
	scenarios.append(_run_replay_restore_scenario())

	var passed := _failures.is_empty()
	for failure in _failures:
		print("[FAIL] %s" % failure)

	var report := {
		"suite": SUITE_NAME,
		"timestamp_utc": Time.get_datetime_string_from_system(true),
		"checks_run": _checks_run,
		"failed_checks": _failures.size(),
		"scenarios": scenarios,
		"passed": passed,
	}

	print("PERSISTENCE_RESILIENCE_REPORT_JSON=%s" % JSON.stringify(report))
	print("Resilience scenarios: %d  Checks: %d  Failed checks: %d" % [
		scenarios.size(),
		_checks_run,
		_failures.size(),
	])

	_cleanup_workspace()
	quit(0 if passed else 1)


func _run_autosave_cadence_scenario() -> Dictionary:
	var scenario_id := "autosave_cadence_non_blocking"
	var scenario_failures: Array[String] = []

	var clock := MockClock.new()
	var consent := MockConsent.new()
	var cloud := MockCloudSync.new()
	var store := FilesystemProjectStore.new(PROJECT_ROOT)
	var autosave := OfflineAutosaveService.new().setup(store, clock, consent, cloud, 1000)

	var actor := PlayerProfile.new("kid-058", PlayerProfile.Role.KID)
	var project := _build_project("project-task058-autosave", "world-task058-autosave")

	_expect(
		autosave.maybe_schedule(project, actor),
		"First autosave should schedule immediately",
		scenario_failures
	)
	clock.advance(500)
	_expect(
		not autosave.maybe_schedule(project, actor),
		"Autosave should be interval-gated before threshold",
		scenario_failures
	)

	autosave.set_interaction_active(true)
	var loop_begin := Time.get_ticks_usec()
	var scheduled_count := 0
	var pending_peak := autosave.get_pending_count()
	for i in range(40):
		clock.advance(1000)
		project.title = "load-%d" % i
		var world := project.get_world("world-task058-autosave")
		if world != null:
			var node := world.find_node("node-task058-autosave")
			if node != null:
				node.properties["coins"] = i
		if autosave.maybe_schedule(project, actor):
			scheduled_count += 1
		pending_peak = maxi(pending_peak, autosave.get_pending_count())
	var loop_msec := float(Time.get_ticks_usec() - loop_begin) / 1000.0

	_expect(
		autosave.process_pending(64) == 0,
		"Queued autosaves should not flush during active interaction",
		scenario_failures
	)
	_expect(
		autosave.get_pending_count() > 0,
		"Pending queue should contain deferred snapshots under active edits",
		scenario_failures
	)
	_expect(
		autosave.get_pending_count() <= OfflineAutosaveService.MAX_PENDING_SNAPSHOTS,
		"Pending queue must stay bounded by MAX_PENDING_SNAPSHOTS",
		scenario_failures
	)

	autosave.set_interaction_active(false)
	consent.grant("kid-058", "cloud_sync")
	var flushed_count := autosave.process_pending(64)
	_expect(
		flushed_count > 0,
		"Deferred autosaves should flush after interaction stops",
		scenario_failures
	)
	_expect(
		not cloud.synced_project_ids.is_empty(),
		"Cloud sync should execute when consent is granted",
		scenario_failures
	)
	_expect(
		loop_msec < 500.0,
		"Autosave scheduling loop should remain non-blocking under active edit load",
		scenario_failures
	)

	return {
		"id": scenario_id,
		"passed": scenario_failures.is_empty(),
		"failures": scenario_failures,
		"metrics": {
			"scheduled_count": scheduled_count,
			"pending_peak": pending_peak,
			"flushed_count": flushed_count,
			"schedule_loop_ms": _round_to(loop_msec, 3),
		},
	}


func _run_replay_restore_scenario() -> Dictionary:
	var scenario_id := "restart_reload_replay_safe_restore"
	var scenario_failures: Array[String] = []

	var world_id := "world-task058-replay"
	var checkpoint_id := "safe_cp_task058"
	var timeline: Array[Dictionary] = []

	var session_a := EventSourcedActionLog.new()
	_append_world_edit(session_a, timeline, world_id, "node-coins", {}, {"coins": 1}, "2026-03-05T13:01:00Z")
	_append_world_edit(session_a, timeline, world_id, "node-coins", {"coins": 1}, {"coins": 2}, "2026-03-05T13:01:01Z")
	session_a.create_checkpoint(world_id, "safe", checkpoint_id)
	_append_world_edit(session_a, timeline, world_id, "node-coins", {"coins": 2}, {"coins": 99}, "2026-03-05T13:01:02Z")

	var risky_state_a := session_a.get_current_state(world_id)
	_expect(
		int(risky_state_a.get("node-coins", {}).get("coins", -1)) == 99,
		"Session A state should include risky edit before safe-restore",
		scenario_failures
	)
	var restored_a := session_a.restore_checkpoint(world_id, checkpoint_id)
	_expect(
		bool(restored_a.get("ok", false)),
		"Session A should restore checkpoint successfully",
		scenario_failures
	)
	var restored_state_a: Dictionary = restored_a.get("state", {})
	_expect(
		int(restored_state_a.get("node-coins", {}).get("coins", -1)) == 2,
		"Session A safe-restore should return pre-risk state",
		scenario_failures
	)

	var journal := {
		"world_id": world_id,
		"checkpoint_id": checkpoint_id,
		"checkpoint_after_entries": 2,
		"entries": timeline,
	}
	_write_json(JOURNAL_FILE, journal)

	var loaded_journal_variant: Variant = _read_json(JOURNAL_FILE)
	_expect(
		loaded_journal_variant is Dictionary,
		"Restart/reload should read persisted event journal",
		scenario_failures
	)
	if not (loaded_journal_variant is Dictionary):
		return {
			"id": scenario_id,
			"passed": false,
			"failures": scenario_failures,
			"metrics": {},
		}

	var loaded_journal: Dictionary = loaded_journal_variant
	var session_b := EventSourcedActionLog.new()
	var entries_variant: Variant = loaded_journal.get("entries", [])
	var entries: Array = entries_variant if entries_variant is Array else []
	var cp_after := int(loaded_journal.get("checkpoint_after_entries", 0))

	for i in range(entries.size()):
		var entry_variant: Variant = entries[i]
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var event := WorldEditedEvent.new(
			world_id,
			str(entry.get("edit_type", "property_changed")),
			"kid-058",
			str(entry.get("timestamp", ""))
		)
		event.event_id = str(entry.get("event_id", ""))
		event.target_node_id = str(entry.get("target_node_id", ""))
		var prev_variant: Variant = entry.get("previous_state", {})
		var next_variant: Variant = entry.get("new_state", {})
		event.previous_state = prev_variant if prev_variant is Dictionary else {}
		event.new_state = next_variant if next_variant is Dictionary else {}
		session_b.record_world_edit(event)

		if i + 1 == cp_after:
			session_b.create_checkpoint(world_id, "safe", checkpoint_id)

	var risky_state_b := session_b.get_current_state(world_id)
	_expect(
		int(risky_state_b.get("node-coins", {}).get("coins", -1)) == 99,
		"Session B replay should reconstruct risky state before restore",
		scenario_failures
	)

	var restored_b := session_b.restore_checkpoint(world_id, checkpoint_id)
	_expect(
		bool(restored_b.get("ok", false)),
		"Session B should restore checkpoint after replay",
		scenario_failures
	)
	var restored_state_b: Dictionary = restored_b.get("state", {})
	_expect(
		int(restored_state_b.get("node-coins", {}).get("coins", -1)) == 2,
		"Session B safe-restore should match Session A stable state",
		scenario_failures
	)
	var session_a_coins := int(restored_state_a.get("node-coins", {}).get("coins", -1))
	var session_b_coins := int(restored_state_b.get("node-coins", {}).get("coins", -1))
	_expect(
		restored_state_a.has("node-coins")
			and restored_state_b.has("node-coins")
			and session_a_coins == session_b_coins,
		"Safe-restore state should remain consistent across sessions",
		scenario_failures
	)

	var replay_project := _build_project("project-task058-replay", world_id)
	var replay_world := replay_project.get_world(world_id)
	if replay_world != null:
		var replay_node := replay_world.find_node("node-task058-autosave")
		if replay_node != null:
			replay_node.node_id = "node-coins"
			replay_node.properties["coins"] = int(restored_state_b.get("node-coins", {}).get("coins", 0))

	var clock := MockClock.new()
	var consent := MockConsent.new()
	var autosave := OfflineAutosaveService.new().setup(
		FilesystemProjectStore.new(PROJECT_ROOT),
		clock,
		consent,
		null,
		1000
	)
	_expect(
		autosave.maybe_schedule(replay_project, PlayerProfile.new("kid-058", PlayerProfile.Role.KID)),
		"Restored project should schedule for persistence",
		scenario_failures
	)
	autosave.process_pending(1)
	var reloaded := FilesystemProjectStore.new(PROJECT_ROOT).load_project("project-task058-replay")
	_expect(
		reloaded != null,
		"Reloaded project should be readable from persisted safe snapshot",
		scenario_failures
	)
	if reloaded != null:
		var reloaded_world := reloaded.get_world(world_id)
		var coins := -1
		if reloaded_world != null:
			var reloaded_node := reloaded_world.find_node("node-coins")
			if reloaded_node != null:
				coins = int(reloaded_node.properties.get("coins", -1))
		_expect(
			coins == 2,
			"Reloaded project should preserve safe-restored world state",
			scenario_failures
		)

	return {
		"id": scenario_id,
		"passed": scenario_failures.is_empty(),
		"failures": scenario_failures,
		"metrics": {
			"events_replayed": entries.size(),
			"checkpoint_after_entries": cp_after,
			"safe_state_coins": int(restored_state_b.get("node-coins", {}).get("coins", -1)),
		},
	}


func _append_world_edit(
	log: EventSourcedActionLog,
	timeline: Array[Dictionary],
	world_id: String,
	target_node_id: String,
	previous: Dictionary,
	next: Dictionary,
	timestamp: String
) -> void:
	var event := WorldEditedEvent.new(world_id, "property_changed", "kid-058", timestamp)
	event.target_node_id = target_node_id
	event.previous_state = {target_node_id: previous.duplicate(true)}
	event.new_state = {target_node_id: next.duplicate(true)}
	log.record_world_edit(event)
	timeline.append({
		"event_id": event.event_id,
		"timestamp": timestamp,
		"edit_type": "property_changed",
		"target_node_id": target_node_id,
		"previous_state": event.previous_state.duplicate(true),
		"new_state": event.new_state.duplicate(true),
	})


func _build_project(project_id: String, world_id: String) -> Project:
	var project := Project.new(project_id, "Task058")
	project.owner_profile_id = "kid-058"
	var world := World.new(world_id, "ResilienceWorld")
	var node := SceneNode.new("node-task058-autosave", SceneNode.NodeType.OBJECT)
	node.display_name = "CoinsNode"
	node.properties = {"coins": 0}
	world.add_node(node)
	project.add_world(world)
	return project


func _expect(condition: bool, message: String, scenario_failures: Array[String]) -> void:
	_checks_run += 1
	if condition:
		return
	scenario_failures.append(message)
	_failures.append(message)


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _write_json(path: String, value: Variant) -> bool:
	var dir := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value))
	return true


func _cleanup_workspace() -> void:
	var root := ProjectSettings.globalize_path("user://task058_persistence_resilience")
	_remove_dir_recursive_absolute(root)


func _remove_dir_recursive_absolute(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var child := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			_remove_dir_recursive_absolute(child)
		else:
			DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _round_to(value: float, digits: int) -> float:
	var factor := pow(10.0, float(digits))
	return round(value * factor) / factor

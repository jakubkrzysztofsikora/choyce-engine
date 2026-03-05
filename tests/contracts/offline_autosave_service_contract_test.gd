class_name OfflineAutosaveServiceContractTest
extends PortContractTest


class MockClock:
	extends ClockPort

	var _now_msec: int = 1000

	func set_now(value: int) -> void:
		_now_msec = value

	func advance(delta: int) -> void:
		_now_msec += delta

	func now_iso() -> String:
		return "2026-03-02T20:00:00Z"

	func now_msec() -> int:
		return _now_msec


class MockProjectStore:
	extends ProjectStorePort

	var saved_projects: Array = []

	func save_project(project: Project) -> bool:
		if project == null:
			return false
		saved_projects.append(project)
		return true

	func load_project(_project_id: String) -> Project:
		return null

	func list_projects() -> Array:
		return saved_projects.duplicate()


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

	var synced_ids: Array[String] = []
	var available: bool = true

	func sync_project(project: Project) -> bool:
		if not available or project == null or project.project_id.strip_edges().is_empty():
			return false
		synced_ids.append(project.project_id)
		return true

	func is_available() -> bool:
		return available


func run() -> Dictionary:
	_reset()

	var service_script_variant: Variant = load("res://src/application/offline_autosave_service.gd")
	_assert_true(service_script_variant is Script, "OfflineAutosaveService script should load")
	if not (service_script_variant is Script):
		return _build_result("OfflineAutosaveService")
	var service_script: Script = service_script_variant

	var clock := MockClock.new()
	var store := MockProjectStore.new()
	var consent := MockConsent.new()
	var cloud := MockCloudSync.new()
	var service: Variant = service_script.new()
	service.call("setup", store, clock, consent, cloud, 30000)

	var project := Project.new("project-35", "Autosave Project")
	project.owner_profile_id = "parent-1"
	var kid := PlayerProfile.new("kid-1", PlayerProfile.Role.KID)

	# 1. First schedule succeeds and persists when processed.
	_assert_true(bool(service.call("maybe_schedule", project, kid)), "First autosave should schedule immediately")
	_assert_true(int(service.call("get_pending_count")) == 1, "Pending queue should contain one snapshot")
	_assert_true(int(service.call("process_pending", 1)) == 1, "One pending snapshot should be processed")
	_assert_true(store.saved_projects.size() == 1, "Local project store should receive autosave snapshot")
	_assert_true(cloud.synced_ids.is_empty(), "Cloud sync should not run without explicit consent")

	# 2. Interval gate blocks re-schedule before 30 seconds.
	_assert_false(bool(service.call("maybe_schedule", project, kid)), "Autosave should not re-schedule before interval")

	clock.advance(30000)
	_assert_true(bool(service.call("maybe_schedule", project, kid)), "Autosave should schedule after interval elapses")

	# 3. Active interaction pauses persistence work.
	service.call("set_interaction_active", true)
	_assert_true(int(service.call("process_pending", 2)) == 0, "No autosave IO should execute while interaction is active")
	_assert_true(int(service.call("get_pending_count")) == 1, "Pending autosave should remain queued during interaction")

	# 4. Consent-gated cloud sync runs after interaction ends.
	consent.grant("parent-1", "parental_control_cloud_sync_consent")
	service.call("set_interaction_active", false)
	_assert_true(int(service.call("process_pending", 2)) == 1, "Queued autosave should flush after interaction ends")
	_assert_true(cloud.synced_ids.size() == 1, "Cloud sync should run once consent is granted")

	# 5. Snapshot must be immutable after scheduling.
	clock.advance(30000)
	var isolated := Project.new("project-iso", "Before")
	_assert_true(bool(service.call("maybe_schedule", isolated, kid)), "Snapshot project should schedule")
	isolated.title = "After"
	service.call("process_pending", 1)
	var saved_variant: Variant = store.saved_projects[store.saved_projects.size() - 1]
	if saved_variant is Project:
		var saved_project: Project = saved_variant
		_assert_true(saved_project.title == "Before", "Saved snapshot should not be mutated by later edits")

	# 6. Queue is bounded to prevent unbounded memory growth.
	for _i in range(12):
		clock.advance(30000)
		service.call("maybe_schedule", project, kid)
	_assert_true(
		int(service.call("get_pending_count")) <= 8,
		"Pending queue should be bounded by MAX_PENDING_SNAPSHOTS"
	)

	# 7. Service should still work without cloud adapter.
	var store_no_cloud := MockProjectStore.new()
	var no_cloud: Variant = service_script.new()
	no_cloud.call("setup", store_no_cloud, clock, consent, null, 30000)
	clock.advance(30000)
	_assert_true(bool(no_cloud.call("maybe_schedule", project, kid)), "Scheduling should work without cloud adapter")
	_assert_true(int(no_cloud.call("process_pending", 1)) == 1, "Local autosave should still persist without cloud adapter")
	_assert_true(store_no_cloud.saved_projects.size() == 1, "Local save should occur in offline-only mode")

	return _build_result("OfflineAutosaveService")

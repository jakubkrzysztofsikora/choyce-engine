extends ApplicationTest

const ManageDataLifecycleServiceScn = preload("res://src/application/manage_data_lifecycle_service.gd")
const PlayerProfileScn = preload("res://src/domain/gameplay/player_profile.gd")
const ParentalControlPolicyScn = preload("res://src/domain/identity_safety/parental_control_policy.gd")
const DataLifecyclePortScn = preload("res://src/ports/outbound/data_lifecycle_port.gd")
const ParentalPolicyStorePortScn = preload("res://src/ports/outbound/parental_policy_store_port.gd")
const AuditLedgerPortScn = preload("res://src/ports/outbound/audit_ledger_port.gd")

var _service: ManageDataLifecycleServiceScn
var _lifecycle_port: MockLifecyclePort
var _policy_store: MockPolicyStore
var _clock: MockClock
var _role_guard: MockRoleGuard
var _audit_ledger: MockAuditLedger


func run() -> Dictionary:
	_setup()
	test_request_export_happy_path()
	test_request_export_requires_cloud_consent()
	test_request_delete_authorized()
	test_request_delete_unauthorized()
	test_managed_subject_scope_enforced()
	test_update_retention_validation()
	test_revoke_consent_cloud_sync()
	return _build_result("ManageDataLifecycleService")


func _setup() -> void:
	_lifecycle_port = MockLifecyclePort.new()
	_policy_store = MockPolicyStore.new()
	_clock = MockClock.new()
	_role_guard = MockRoleGuard.new()
	_audit_ledger = MockAuditLedger.new()

	_service = ManageDataLifecycleServiceScn.new().setup(
		_lifecycle_port,
		_role_guard,
		_clock,
		_audit_ledger,
		_policy_store
	)


func test_request_export_happy_path() -> void:
	var parent = _authorized_parent("parent_1", ["kid_1"])
	var kid_id := "kid_1"

	var result = _service.request_export(parent, kid_id)
	_assert_true(result.get("ok", false), "Export queued successfully")
	_assert_eq(result.get("job_id", ""), "JOB-123", "Job ID returned")

	var last_req = _lifecycle_port.last_export_request
	_assert_eq(last_req.get("subject_id"), kid_id, "Subject ID passed correctly")


func test_request_export_requires_cloud_consent() -> void:
	var parent = _authorized_parent("parent_2", ["kid_2"])
	var kid_id := "kid_2"

	# Missing consent should block cloud-scope export.
	var blocked = _service.request_export(parent, kid_id, {"requires_cloud_consent": true})
	_assert_false(blocked.get("ok", true), "Cloud export blocked when consent missing")
	_assert_eq(blocked.get("error", ""), "Cloud consent required", "Consent error is explicit")

	_policy_store.set_initial_policy(kid_id, true)
	var allowed = _service.request_export(parent, kid_id, {"requires_cloud_consent": true})
	_assert_true(allowed.get("ok", false), "Cloud export allowed with consent")


func test_request_delete_authorized() -> void:
	var parent = _authorized_parent("parent_3", ["kid_3"])
	var kid_id := "kid_3"

	var result = _service.request_delete(parent, kid_id)
	_assert_true(result.get("ok", false), "Delete queued successfully")
	_assert_eq(_lifecycle_port.last_delete_request.get("subject_id", ""), kid_id, "Delete payload has subject")


func test_request_delete_unauthorized() -> void:
	var imposter = PlayerProfileScn.new("kid_unauthorized", PlayerProfileScn.Role.KID)
	var kid_id := "kid_1"

	var result = _service.request_delete(imposter, kid_id)
	_assert_false(result.get("ok", true), "Delete blocked for kid")
	_assert_eq(result.get("error", ""), "Unauthorized data deletion request", "Reason correct")


func test_managed_subject_scope_enforced() -> void:
	var parent = _authorized_parent("parent_scope", ["kid_allowed"])

	var denied = _service.request_export(parent, "kid_not_managed")
	_assert_false(denied.get("ok", true), "Parent cannot export unmanaged child profile")
	_assert_eq(denied.get("error", ""), "Unauthorized data export request", "Scope denial reported")


func test_update_retention_validation() -> void:
	var parent = _authorized_parent("parent_retention", ["kid_retention"])
	var kid_id := "kid_retention"

	var invalid = _service.update_retention(parent, kid_id, {"keep_days": 0})
	_assert_false(invalid, "Invalid retention policy is rejected")

	var valid = _service.update_retention(parent, kid_id, {"keep_days": 365})
	_assert_true(valid, "Valid retention policy is accepted")
	_assert_eq(
		int(_lifecycle_port.last_retention_update.get("retention_policy", {}).get("keep_days", -1)),
		365,
		"Retention payload stores keep_days"
	)


func test_revoke_consent_cloud_sync() -> void:
	var parent = _authorized_parent("parent_4", ["kid_4"])
	var kid_id := "kid_4"

	_policy_store.set_initial_policy(kid_id, true) # Cloud sync enabled.

	var success = _service.revoke_consent(parent, kid_id, "cloud_sync")
	_assert_true(success, "Revocation successful")

	# Verify policy updated locally.
	var updated = _policy_store.load_policy(kid_id)
	_assert_false(updated.cloud_sync_consent, "Cloud sync consent set to false")

	# Verify backend call.
	_assert_eq(_lifecycle_port.last_retention_update.get("consent_revoked"), "cloud_sync", "Backend notified")
	_assert_false(
		bool(_lifecycle_port.last_retention_update.get("retention_policy", {}).get("cloud_sync_consent", true)),
		"Retention payload revokes cloud consent"
	)

	# Verify audit entries were appended.
	_assert_true(_audit_ledger.records.size() >= 1, "Lifecycle actions append audit records")


func _authorized_parent(parent_id: String, managed_profiles: Array[String]) -> PlayerProfileScn:
	var parent = PlayerProfileScn.new(parent_id, PlayerProfileScn.Role.PARENT)
	parent.preferences["managed_profiles"] = managed_profiles.duplicate()
	_role_guard.authorize(parent.profile_id)
	return parent


# =============================================================================
# Mocks
# =============================================================================

class MockLifecyclePort extends DataLifecyclePortScn:
	var last_export_request: Dictionary = {}
	var last_delete_request: Dictionary = {}
	var last_retention_update: Dictionary = {}

	func enqueue_export(payload: Dictionary) -> Dictionary:
		last_export_request = payload.duplicate(true)
		return {"ok": true, "job_id": "JOB-123"}

	func enqueue_delete(payload: Dictionary) -> Dictionary:
		last_delete_request = payload.duplicate(true)
		return {"ok": true, "job_id": "DEL-456"}

	func update_retention(payload: Dictionary) -> bool:
		last_retention_update = payload.duplicate(true)
		return true


class MockPolicyStore extends ParentalPolicyStorePortScn:
	var policies: Dictionary = {} # id -> policy

	func set_initial_policy(id: String, cloud_sync: bool) -> void:
		var policy = ParentalControlPolicyScn.new()
		policy.cloud_sync_consent = cloud_sync
		policies[id] = policy

	func load_policy(id: String) -> ParentalControlPolicyScn:
		if policies.has(id):
			return policies[id]
		return null

	func save_policy(id: String, policy: ParentalControlPolicyScn) -> bool:
		policies[id] = policy
		return true


class MockAuditLedger extends AuditLedgerPortScn:
	var records: Array = []
	var _last_hash := ""

	func append_record(record: AuditRecord) -> bool:
		records.append(record)
		_last_hash = record.record_hash
		return true

	func get_records(_filter: Dictionary = {}) -> Array:
		return records.duplicate(true)

	func verify_integrity() -> Dictionary:
		return {"ok": true, "total_records": records.size(), "last_valid_index": records.size() - 1}

	func record_count() -> int:
		return records.size()

	func last_hash() -> String:
		return _last_hash


class MockRoleGuard extends RoleTokenGuard:
	var authorized_parents: Array[String] = []

	func authorize(id: String) -> void:
		authorized_parents.append(id)

	func verify_parent_profile(profile: PlayerProfile) -> bool:
		return profile.is_parent() and profile.profile_id in authorized_parents


class MockClock extends ClockPort:
	func now_iso() -> String:
		return "2026-03-05T12:00:00Z"

	func now_msec() -> int:
		return 1772700000000

## Application service: implementation of data lifecycle management (Export/Delete/Retention).
## Ensures strict parental authorization for COPPA/GDPR compliance actions.
class_name ManageDataLifecycleService
extends ManageDataLifecyclePort

var _lifecycle_port: DataLifecyclePort
var _role_guard: RoleTokenGuard
var _clock: ClockPort
var _audit_ledger: AuditLedgerPort
var _policy_store: ParentalPolicyStorePort

func setup(
	lifecycle_port: DataLifecyclePort,
	role_guard: RoleTokenGuard = null,
	clock: ClockPort = null,
	audit_ledger: AuditLedgerPort = null,
	policy_store: ParentalPolicyStorePort = null
) -> ManageDataLifecycleService:
	_lifecycle_port = lifecycle_port
	_role_guard = role_guard
	_clock = clock
	_audit_ledger = audit_ledger
	_policy_store = policy_store
	return self


func request_export(
	parent: PlayerProfile,
	subject_profile_id: String,
	scope: Dictionary = {}
) -> Dictionary:
	if _lifecycle_port == null:
		return {"ok": false, "error": "Lifecycle backend unavailable"}
	if not _is_authorized(parent, subject_profile_id):
		return {"ok": false, "error": "Unauthorized data export request"}
	if bool(scope.get("requires_cloud_consent", false)):
		if not _has_required_cloud_consent(subject_profile_id):
			return {"ok": false, "error": "Cloud consent required"}

	var payload := {
		"requester_id": parent.profile_id,
		"subject_id": subject_profile_id,
		"scope": scope,
		"created_at": _timestamp()
	}
	
	_log_audit("DATA_EXPORT_REQUESTED", parent.profile_id, subject_profile_id)
	
	# Forward to backend
	return _lifecycle_port.enqueue_export(payload)


func request_delete(
	parent: PlayerProfile,
	subject_profile_id: String,
	scope: Dictionary = {}
) -> Dictionary:
	if _lifecycle_port == null:
		return {"ok": false, "error": "Lifecycle backend unavailable"}
	if not _is_authorized(parent, subject_profile_id):
		return {"ok": false, "error": "Unauthorized data deletion request"}

	var payload := {
		"requester_id": parent.profile_id,
		"subject_id": subject_profile_id,
		"scope": scope,
		"created_at": _timestamp()
	}
	
	_log_audit("DATA_DELETION_REQUESTED", parent.profile_id, subject_profile_id)
	
	return _lifecycle_port.enqueue_delete(payload)


func update_retention(
	parent: PlayerProfile,
	subject_profile_id: String,
	policy: Dictionary
) -> bool:
	if _lifecycle_port == null:
		return false
	if not _is_authorized(parent, subject_profile_id):
		return false
	if not _is_valid_retention_policy(policy):
		return false
		
	var payload := {
		"requester_id": parent.profile_id,
		"subject_id": subject_profile_id,
		"retention_policy": policy,
		"updated_at": _timestamp()
	}
	
	_log_audit("RETENTION_POLICY_UPDATED", parent.profile_id, subject_profile_id)
	
	return _lifecycle_port.update_retention(payload)


func revoke_consent(
	parent: PlayerProfile,
	subject_profile_id: String,
	consent_key: String
) -> bool:
	if _lifecycle_port == null:
		return false
	if not _is_authorized(parent, subject_profile_id):
		return false
	if consent_key.strip_edges().is_empty():
		return false

	var consent_key_clean := consent_key.strip_edges().to_lower()

	# Update local policy store if applicable.
	if _policy_store != null:
		var current_policy := _policy_store.load_policy(subject_profile_id)
		if current_policy != null:
			if consent_key_clean == "cloud_sync":
				var new_policy := ParentalControlPolicy.new(
					current_policy.daily_playtime_limit_minutes,
					current_policy.session_playtime_limit_minutes,
					current_policy.ai_access,
					current_policy.sharing_allowed,
					current_policy.language_override_allowed,
					false # cloud_sync_consent = false
				)
				if not _policy_store.save_policy(subject_profile_id, new_policy):
					return false

	# Notify backend with explicit revocation payload.
	var revocation_policy := {}
	if consent_key_clean == "cloud_sync":
		revocation_policy["cloud_sync_consent"] = false

	var retention_payload := {
		"requester_id": parent.profile_id,
		"subject_id": subject_profile_id,
		"consent_revoked": consent_key_clean,
		"retention_policy": revocation_policy,
		"updated_at": _timestamp()
	}
	
	_log_audit("CONSENT_REVOKED", parent.profile_id, subject_profile_id, consent_key_clean)
	
	var backend_ack := _lifecycle_port.update_retention(retention_payload)
	return backend_ack


func _is_authorized(actor: PlayerProfile, subject_id: String) -> bool:
	# COPPA §312.10 — log every authorization attempt regardless of outcome.
	# Returns true only when actor is a verified parent who manages the subject.
	var actor_id := actor.profile_id if actor != null else "<null>"
	if actor == null or subject_id.strip_edges().is_empty():
		_log_audit_denial("DATA_AUTH_DENIED", actor_id, subject_id, "actor or subject missing")
		return false
	if not actor.is_parent():
		_log_audit_denial("DATA_AUTH_DENIED", actor_id, subject_id, "actor is not parent role")
		return false
	if _role_guard != null and not _role_guard.verify_parent_profile(actor):
		_log_audit_denial("DATA_AUTH_DENIED", actor_id, subject_id, "role guard rejected parent token")
		return false
	if not _is_subject_managed_by_parent(actor, subject_id):
		_log_audit_denial("DATA_AUTH_DENIED", actor_id, subject_id, "subject not in managed_profiles")
		return false
	return true


func _timestamp() -> String:
	if _clock != null:
		return _clock.now_iso()
	return ""


func _is_subject_managed_by_parent(parent: PlayerProfile, subject_id: String) -> bool:
	# Safety default: empty or missing managed_profiles → DENY. Prior default-allow
	# collapsed authorization to a single env var (CHOYCE_PROFILE_ROLE=parent).
	# Caller must explicitly populate parent.preferences.managed_profiles at
	# profile-build time. Non-Array preferences also denied as defensive guard.
	var managed_variant: Variant = parent.preferences.get("managed_profiles", [])
	if not (managed_variant is Array):
		return false
	var managed_profiles: Array = managed_variant
	if managed_profiles.is_empty():
		return false
	return managed_profiles.has(subject_id)


func _has_required_cloud_consent(subject_profile_id: String) -> bool:
	if _policy_store == null:
		return false
	var policy := _policy_store.load_policy(subject_profile_id)
	if policy == null:
		return false
	return policy.cloud_sync_consent


func _is_valid_retention_policy(policy: Dictionary) -> bool:
	if policy.is_empty():
		return false
	if policy.has("keep_days"):
		var keep_days := int(policy.get("keep_days", 0))
		if keep_days < 1 or keep_days > 3650:
			return false
	return true


## COPPA §312.10: emit an audit record on every denied authorization attempt
## so failed access leaves a forensic trail. Reason is a short free-text string
## describing the specific check that rejected the request.
func _log_audit_denial(action: String, actor: String, subject: String, reason: String) -> void:
	_log_audit(action, actor, subject, reason)


func _log_audit(action: String, actor: String, subject: String, detail: String = "") -> void:
	if _audit_ledger != null:
		var record_suffix := str(_clock.now_msec()) if _clock != null else str(Time.get_ticks_msec())
		var payload := {
			"subject_profile_id": subject,
			"detail": detail,
		}
		var record_id := "lifecycle_%s_%s" % [action.to_lower(), record_suffix]
		var record := AuditRecord.new(
			record_id,
			action,
			record_id,
			actor,
			_timestamp(),
			payload,
			_audit_ledger.last_hash()
		)
		_audit_ledger.append_record(record)

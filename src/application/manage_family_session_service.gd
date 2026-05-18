class_name ManageFamilySessionService
extends ManageFamilySessionPort

var _gateway: FamilySessionGatewayPort
var _policy_store: ParentalPolicyStorePort
var _feature_flags: FeatureFlagService
var _clock: ClockPort
var _event_bus: DomainEventBus


func setup(
	gateway: FamilySessionGatewayPort,
	policy_store: ParentalPolicyStorePort = null,
	feature_flags: FeatureFlagService = null,
	clock: ClockPort = null,
	event_bus: DomainEventBus = null
) -> ManageFamilySessionService:
	_gateway = gateway
	_policy_store = policy_store
	_feature_flags = feature_flags
	_clock = clock
	_event_bus = event_bus
	return self


func create_invite(
	family_id: String,
	host: PlayerProfile,
	world_id: String,
	expires_minutes: int = 30
) -> Dictionary:
	if not _is_online_enabled():
		return {
			"ok": false,
			"error": "Online sessions disabled by deployment policy",
		}
	if _gateway == null:
		return {"ok": false, "error": "Session gateway unavailable"}
	if host == null:
		return {"ok": false, "error": "Host profile is required"}
	if family_id.strip_edges().is_empty():
		return {"ok": false, "error": "Family ID is required"}
	if world_id.strip_edges().is_empty():
		return {"ok": false, "error": "World ID is required"}
	var host_family_id := _family_id_for_actor(host)
	if not host_family_id.is_empty() and host_family_id != family_id:
		return {"ok": false, "error": "Host family mismatch"}

	if host.is_kid():
		var policy_gate := _ensure_sharing_policy_allows(family_id)
		if not bool(policy_gate.get("ok", false)):
			return policy_gate

	var payload := {
		"family_id": family_id,
		"host_id": host.profile_id,
		"host_role": _role_name(host),
		"world_id": world_id,
		"expires_minutes": expires_minutes,
		"created_at": _clock.now_iso() if _clock else ""
	}

	var result := _gateway.create_invite(payload)
	
	if result.get("ok", false) and _event_bus != null:
		# Event type pending dedicated domain event class.
		pass
		
	return result


func join_session(invite_code: String, actor: PlayerProfile) -> Dictionary:
	if not _is_online_enabled():
		return {
			"ok": false,
			"error": "Online sessions disabled by deployment policy",
		}
	if _gateway == null:
		return {"ok": false, "error": "Session gateway unavailable"}
	if actor == null:
		return {"ok": false, "error": "Actor profile is required"}
	if invite_code.strip_edges().is_empty():
		return {"ok": false, "error": "Invite code is required"}

	var actor_family_id := _family_id_for_actor(actor)
	if actor_family_id.strip_edges().is_empty():
		return {"ok": false, "error": "Family context required for join"}
	if actor.is_kid():
		var policy_gate := _ensure_sharing_policy_allows(actor_family_id)
		if not bool(policy_gate.get("ok", false)):
			return policy_gate

	var payload := {
		"invite_code": invite_code,
		"actor_id": actor.profile_id,
		"actor_role": _role_name(actor),
		"family_id": actor_family_id,
	}

	var result := _gateway.join_session(payload)
	
	if result.get("ok", false) and _event_bus != null:
		# Event type pending dedicated domain event class.
		pass

	return result


func close_session(session_id: String, actor: PlayerProfile, reason: String = "") -> bool:
	if not _is_online_enabled():
		return false
	if _gateway == null:
		return false
	if actor == null:
		return false
	if session_id.strip_edges().is_empty():
		return false

	var actor_family_id := _family_id_for_actor(actor)
	if actor_family_id.strip_edges().is_empty():
		return false
	if actor.is_kid():
		var policy_gate := _ensure_sharing_policy_allows(actor_family_id)
		if not bool(policy_gate.get("ok", false)):
			return false

	var payload := {
		"session_id": session_id,
		"actor_id": actor.profile_id,
		"actor_role": _role_name(actor),
		"family_id": actor_family_id,
		"reason": reason,
	}
	
	return _gateway.close_session(payload)


func _is_online_enabled() -> bool:
	return _feature_flags == null or _feature_flags.is_enabled("online_family_sessions")


func _family_id_for_actor(actor: PlayerProfile) -> String:
	if actor == null:
		return ""
	return str(actor.preferences.get("family_id", "")).strip_edges()


func _role_name(actor: PlayerProfile) -> String:
	if actor == null:
		return ""
	return "parent" if actor.is_parent() else "kid"


func _ensure_sharing_policy_allows(policy_id: String) -> Dictionary:
	if _policy_store == null:
		return {"ok": false, "error": "Parental policy store unavailable"}
	var policy := _policy_store.load_policy(policy_id)
	if policy == null:
		return {"ok": false, "error": "Parental policy not found"}
	if not policy.sharing_allowed:
		return {"ok": false, "error": "Sharing not allowed by parental policy"}
	return {"ok": true}

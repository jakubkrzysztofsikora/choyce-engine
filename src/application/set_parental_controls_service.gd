## Application service: updates parental control settings.
## Validates that the caller is a parent, loads the current policy,
## applies changes, persists the new policy, emits a domain event
## for audit, and logs with attribution via telemetry.
class_name SetParentalControlsService
extends SetParentalControlsPort

var _identity: IdentityConsentPort
var _clock: ClockPort
var _telemetry: TelemetryPort
var _policy_store: ParentalPolicyStorePort
var _event_bus: DomainEventBus
var _role_token_guard: RoleTokenGuard

## Allowed setting keys and their expected value types for validation.
const VALID_SETTINGS := [
	"playtime_limit",
	"ai_access",
	"sharing_permissions",
	"language_override",
	"cloud_sync_consent",
]


func setup(
	identity: IdentityConsentPort,
	clock: ClockPort,
	telemetry: TelemetryPort,
	policy_store: ParentalPolicyStorePort = null,
	event_bus: DomainEventBus = null,
	role_token_guard: RoleTokenGuard = null
) -> SetParentalControlsService:
	_identity = identity
	_clock = clock
	_telemetry = telemetry
	_policy_store = policy_store
	_event_bus = event_bus
	_role_token_guard = role_token_guard
	return self


func execute(parent: PlayerProfile, settings: Dictionary) -> bool:
	# Only parents can modify parental controls
	if parent == null or not parent.is_parent():
		return false
	if _role_token_guard != null and not _role_token_guard.verify_parent_profile(parent):
		return false

	# Validate setting keys
	for key in settings:
		if key not in VALID_SETTINGS:
			return false

	# Load current policy (or create defaults)
	var previous_policy := _load_current_policy(parent.profile_id)
	var previous_dict := previous_policy.to_dict()

	# Build the new policy from current + changes
	var new_policy := _apply_settings(previous_policy, settings)
	var new_dict := new_policy.to_dict()

	# Persist updated policy
	if _policy_store != null:
		if not _policy_store.save_policy(parent.profile_id, new_policy):
			return false

	# Apply each setting via consent port (backward compat)
	for key in settings:
		var consent_type := "parental_control_%s" % key
		_identity.request_consent(parent.profile_id, consent_type)

	# Emit domain event for audit ledger
	var now := _clock.now_iso()
	_emit_policy_updated_event(parent.profile_id, previous_dict, new_dict, now)

	# Log the change for telemetry
	_telemetry.emit_event("parental_controls_updated", {
		"parent_id": parent.profile_id,
		"settings_changed": settings.keys(),
		"timestamp": now,
	})

	return true


func _load_current_policy(parent_id: String) -> ParentalControlPolicy:
	if _policy_store != null:
		var loaded := _policy_store.load_policy(parent_id)
		if loaded != null:
			return loaded
	return ParentalControlPolicy.new()


func _apply_settings(
	current: ParentalControlPolicy,
	settings: Dictionary
) -> ParentalControlPolicy:
	var daily_limit := current.daily_playtime_limit_minutes
	var session_limit := current.session_playtime_limit_minutes
	var ai_access := current.ai_access
	var sharing := current.sharing_allowed
	var lang_override := current.language_override_allowed
	var cloud_sync := current.cloud_sync_consent

	if settings.has("playtime_limit"):
		var limit_val: Variant = settings["playtime_limit"]
		if limit_val is Dictionary:
			daily_limit = int((limit_val as Dictionary).get("daily", daily_limit))
			session_limit = int((limit_val as Dictionary).get("session", session_limit))
		elif limit_val is int or limit_val is float:
			daily_limit = int(limit_val)

	if settings.has("ai_access"):
		var access_val: Variant = settings["ai_access"]
		if access_val is String:
			ai_access = ParentalControlPolicy._ai_access_from_string(access_val as String)

	if settings.has("sharing_permissions"):
		sharing = bool(settings["sharing_permissions"])

	if settings.has("language_override"):
		lang_override = bool(settings["language_override"])

	if settings.has("cloud_sync_consent"):
		cloud_sync = bool(settings["cloud_sync_consent"])

	return ParentalControlPolicy.new(
		daily_limit, session_limit, ai_access,
		sharing, lang_override, cloud_sync
	)


func _emit_policy_updated_event(
	parent_id: String,
	previous_dict: Dictionary,
	new_dict: Dictionary,
	timestamp: String
) -> void:
	if _event_bus == null:
		return

	var change_type := "update"
	if previous_dict == new_dict:
		return  # No actual change

	var event := ParentalPolicyUpdatedEvent.new(parent_id, timestamp)
	event.previous_policy = previous_dict
	event.new_policy = new_dict
	event.change_type = change_type
	_event_bus.emit(event)

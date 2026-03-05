## Value object representing a parent's control policy for their child.
## Covers playtime limits, AI access level, sharing permissions,
## language overrides, and cloud sync consent. Immutable once created;
## changes produce a new policy instance.
class_name ParentalControlPolicy
extends RefCounted

## AI access level for the child.
enum AIAccessLevel { DISABLED, CREATIVE_ONLY, FULL }

## Default daily playtime limit in minutes (0 = unlimited).
const DEFAULT_DAILY_LIMIT_MINUTES: int = 60
## Default per-session limit in minutes (0 = unlimited).
const DEFAULT_SESSION_LIMIT_MINUTES: int = 30

var daily_playtime_limit_minutes: int
var session_playtime_limit_minutes: int
var ai_access: AIAccessLevel
var sharing_allowed: bool
var language_override_allowed: bool
var cloud_sync_consent: bool


func _init(
	p_daily_limit: int = DEFAULT_DAILY_LIMIT_MINUTES,
	p_session_limit: int = DEFAULT_SESSION_LIMIT_MINUTES,
	p_ai_access: AIAccessLevel = AIAccessLevel.CREATIVE_ONLY,
	p_sharing: bool = false,
	p_language_override: bool = false,
	p_cloud_sync: bool = false
) -> void:
	daily_playtime_limit_minutes = maxi(0, p_daily_limit)
	session_playtime_limit_minutes = maxi(0, p_session_limit)
	ai_access = p_ai_access
	sharing_allowed = p_sharing
	language_override_allowed = p_language_override
	cloud_sync_consent = p_cloud_sync


func is_ai_disabled() -> bool:
	return ai_access == AIAccessLevel.DISABLED


func is_ai_creative_only() -> bool:
	return ai_access == AIAccessLevel.CREATIVE_ONLY


func is_ai_full() -> bool:
	return ai_access == AIAccessLevel.FULL


func has_playtime_limit() -> bool:
	return daily_playtime_limit_minutes > 0


func has_session_limit() -> bool:
	return session_playtime_limit_minutes > 0


func to_dict() -> Dictionary:
	return {
		"daily_playtime_limit_minutes": daily_playtime_limit_minutes,
		"session_playtime_limit_minutes": session_playtime_limit_minutes,
		"ai_access": _ai_access_to_string(ai_access),
		"sharing_allowed": sharing_allowed,
		"language_override_allowed": language_override_allowed,
		"cloud_sync_consent": cloud_sync_consent,
	}


static func from_dict(data: Dictionary) -> ParentalControlPolicy:
	return ParentalControlPolicy.new(
		int(data.get("daily_playtime_limit_minutes", DEFAULT_DAILY_LIMIT_MINUTES)),
		int(data.get("session_playtime_limit_minutes", DEFAULT_SESSION_LIMIT_MINUTES)),
		_ai_access_from_string(str(data.get("ai_access", "creative_only"))),
		bool(data.get("sharing_allowed", false)),
		bool(data.get("language_override_allowed", false)),
		bool(data.get("cloud_sync_consent", false)),
	)


func equals(other: ParentalControlPolicy) -> bool:
	if other == null:
		return false
	return (
		daily_playtime_limit_minutes == other.daily_playtime_limit_minutes
		and session_playtime_limit_minutes == other.session_playtime_limit_minutes
		and ai_access == other.ai_access
		and sharing_allowed == other.sharing_allowed
		and language_override_allowed == other.language_override_allowed
		and cloud_sync_consent == other.cloud_sync_consent
	)


static func _ai_access_to_string(level: AIAccessLevel) -> String:
	match level:
		AIAccessLevel.DISABLED:
			return "disabled"
		AIAccessLevel.FULL:
			return "full"
		_:
			return "creative_only"


static func _ai_access_from_string(value: String) -> AIAccessLevel:
	match value.strip_edges().to_lower():
		"disabled":
			return AIAccessLevel.DISABLED
		"full":
			return AIAccessLevel.FULL
		_:
			return AIAccessLevel.CREATIVE_ONLY

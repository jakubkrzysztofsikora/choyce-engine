## Value object representing a parent's control policy for their child.
## Covers playtime limits, AI access level, sharing permissions,
## language overrides, and cloud sync consent. Immutable once created;
## changes produce a new policy instance.
class_name ParentalControlPolicy
extends RefCounted

## AI access level for the child.
enum AIAccessLevel { DISABLED, CREATIVE_ONLY, FULL }
## Combat difficulty level (Adv BB P0-7)
enum CombatDifficulty { EASY, NORMAL }

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
## Combat / wave-respawn enabled? Default false (kid-safe per
## CLAUDE.md "Prioritize child safety and parental controls"). Parent
## opts in for older kids who play Roblox-style obby/combat.
var combat_enabled: bool
## Combat difficulty setting (Adv BB P0-7): EASY reduces enemy HP and damage
var combat_difficulty: CombatDifficulty = CombatDifficulty.EASY
## Maximum wave number the WaveDirector will spawn. 0 = no waves
## past the starter pack. Caps frustration spiral for younger kids
## (Adv 2 H-3 fix).
var combat_wave_cap: int


func _init(
	p_daily_limit: int = DEFAULT_DAILY_LIMIT_MINUTES,
	p_session_limit: int = DEFAULT_SESSION_LIMIT_MINUTES,
	p_ai_access: AIAccessLevel = AIAccessLevel.CREATIVE_ONLY,
	p_sharing: bool = false,
	p_language_override: bool = false,
	p_cloud_sync: bool = false,
	p_combat_enabled: bool = true,
	p_combat_wave_cap: int = 0,
	p_combat_difficulty: CombatDifficulty = CombatDifficulty.EASY
) -> void:
	daily_playtime_limit_minutes = maxi(0, p_daily_limit)
	session_playtime_limit_minutes = maxi(0, p_session_limit)
	ai_access = p_ai_access
	sharing_allowed = p_sharing
	language_override_allowed = p_language_override
	cloud_sync_consent = p_cloud_sync
	combat_enabled = p_combat_enabled
	combat_wave_cap = maxi(0, p_combat_wave_cap)
	combat_difficulty = p_combat_difficulty


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
		"combat_enabled": combat_enabled,
		"combat_difficulty": _combat_difficulty_to_string(combat_difficulty),
		"combat_wave_cap": combat_wave_cap,
	}


## Friendly default for first-run kid profiles. Distinct from
## deny_all (which is the fallback for *corrupted* policy). Adv P
## A2 fix: brand-new profile with no stored policy was getting
## 60-second session brick + everything disabled, dead-ending the
## kid. This is the policy used when stored == null AND we have
## a real profile id.
static func default_for_first_run() -> ParentalControlPolicy:
	return ParentalControlPolicy.new(
		DEFAULT_DAILY_LIMIT_MINUTES,       # 60 min daily
		DEFAULT_SESSION_LIMIT_MINUTES,     # 30 min per session
		AIAccessLevel.CREATIVE_ONLY,
		false,                              # sharing off
		false,                              # language override off
		false,                              # cloud sync off
		true,                               # combat on (kid-safe with caps)
		5                                   # wave cap so first runs aren't endless
	)


## Single decision for which policy governs a play session.
## `has_stored` comes from ParentalPolicyStorePort.has_policy(); `stored` is
## the load_policy() result. Absence and an unreadable/deny-all read are
## distinct: a genuinely-new kid (nothing stored) gets the friendly first-run
## default (combat on), while a present-but-unreadable policy fails closed to
## deny_all. Without has_stored these collapse — the encrypted vault returns
## deny_all() for a brand-new kid, so a `stored == null` check alone would
## silently disable combat for every first session.
static func resolve_for_session(
	has_stored: bool,
	stored: ParentalControlPolicy
) -> ParentalControlPolicy:
	if not has_stored:
		return default_for_first_run()
	if stored == null or not (stored is ParentalControlPolicy):
		return deny_all()
	return stored


## Returns the most restrictive policy possible.
## Used as a safety fallback when stored policy cannot be decrypted or is
## absent. Follows the CLAUDE.md "consent → deny" rule.
static func deny_all() -> ParentalControlPolicy:
	return ParentalControlPolicy.new(
		1,                         # 1-minute daily limit (non-zero = enforced)
		1,                         # 1-minute session limit
		AIAccessLevel.DISABLED,    # AI fully off
		false,                     # sharing blocked
		false,                     # language override blocked
		false,                     # cloud sync off
		false,                     # combat off (Adv 2 TB-1 fix)
		0                          # waves disabled past starter pack
	)


static func from_dict(data: Dictionary) -> ParentalControlPolicy:
	return ParentalControlPolicy.new(
		int(data.get("daily_playtime_limit_minutes", DEFAULT_DAILY_LIMIT_MINUTES)),
		int(data.get("session_playtime_limit_minutes", DEFAULT_SESSION_LIMIT_MINUTES)),
		_ai_access_from_string(str(data.get("ai_access", "creative_only"))),
		bool(data.get("sharing_allowed", false)),
		bool(data.get("language_override_allowed", false)),
		bool(data.get("cloud_sync_consent", false)),
		bool(data.get("combat_enabled", true)),
		_combat_difficulty_from_string(str(data.get("combat_difficulty", "easy"))),
		int(data.get("combat_wave_cap", 0)),
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
		and combat_enabled == other.combat_enabled
		and combat_difficulty == other.combat_difficulty
		and combat_wave_cap == other.combat_wave_cap
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


static func _combat_difficulty_to_string(difficulty: CombatDifficulty) -> String:
	match difficulty:
		CombatDifficulty.EASY:
			return "easy"
		CombatDifficulty.NORMAL:
			return "normal"
		_:
			return "easy"


static func _combat_difficulty_from_string(value: String) -> CombatDifficulty:
	match value.strip_edges().to_lower():
		"normal":
			return CombatDifficulty.NORMAL
		_:
			return CombatDifficulty.EASY

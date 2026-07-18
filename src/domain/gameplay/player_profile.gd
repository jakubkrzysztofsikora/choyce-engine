## Entity representing a user profile (Kid or Parent).
## Carries role, age band, and language preference. Used by
## Identity & Safety context for policy decisions and by
## AI Orchestration for prompt envelope construction.
class_name PlayerProfile
extends RefCounted

enum Role { KID, PARENT }

var profile_id: String
var display_name: String
var role: Role
var age_band: AgeBand
var language: String
var preferences: Dictionary


func _init(p_id: String = "", p_role: Role = Role.KID) -> void:
	profile_id = p_id
	display_name = ""
	role = p_role
	age_band = AgeBand.new(
		AgeBand.Band.CHILD_6_8 if p_role == Role.KID else AgeBand.Band.PARENT
	)
	language = "pl-PL"
	preferences = {}


func is_kid() -> bool:
	return role == Role.KID


func is_parent() -> bool:
	return role == Role.PARENT


func is_restricted() -> bool:
	return is_kid() and age_band.is_restricted()


## Serialize to dictionary for persistence
func to_dict() -> Dictionary:
	return {
		"profile_id": profile_id,
		"display_name": display_name,
		"role": role,
		"age_band": age_band.to_dict() if age_band else {},
		"language": language,
		"preferences": preferences.duplicate(true)
	}


## Deserialize from dictionary
static func from_dict(data: Dictionary) -> PlayerProfile:
	var profile := PlayerProfile.new()
	if data.has("profile_id"):
		profile.profile_id = String(data["profile_id"])
	if data.has("display_name"):
		profile.display_name = String(data["display_name"])
	if data.has("role"):
		var role_str := str(data["role"])
		if role_str == "PARENT":
			profile.role = Role.PARENT
		else:
			profile.role = Role.KID
	if data.has("age_band") and data["age_band"] is Dictionary:
		profile.age_band = AgeBand.from_dict(data["age_band"])
	if data.has("language"):
		profile.language = String(data["language"])
	if data.has("preferences") and data["preferences"] is Dictionary:
		profile.preferences = (data["preferences"] as Dictionary).duplicate(true)
	return profile

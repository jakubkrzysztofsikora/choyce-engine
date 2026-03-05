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

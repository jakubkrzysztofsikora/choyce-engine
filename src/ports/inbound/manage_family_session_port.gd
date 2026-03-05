## Inbound use-case port for private family online sessions.
## Handles invite lifecycle, join flow, and host/session closure with role checks.
class_name ManageFamilySessionPort
extends RefCounted


func create_invite(
	family_id: String,
	host: PlayerProfile,
	world_id: String,
	expires_minutes: int = 30
) -> Dictionary:
	push_error("ManageFamilySessionPort.create_invite() not implemented")
	return {}


func join_session(invite_code: String, actor: PlayerProfile) -> Dictionary:
	push_error("ManageFamilySessionPort.join_session() not implemented")
	return {}


func close_session(session_id: String, actor: PlayerProfile, reason: String = "") -> bool:
	push_error("ManageFamilySessionPort.close_session() not implemented")
	return false

## Application-level verifier for parent role tokens.
## Enforces defense-in-depth for parent-only mutations when enabled.
class_name RoleTokenGuard
extends RefCounted

var _clock: ClockPort
var _secret: PackedByteArray = PackedByteArray()


func setup(clock: ClockPort, secret: PackedByteArray) -> RoleTokenGuard:
	_clock = clock
	_secret = secret
	return self


func is_enabled() -> bool:
	return _clock != null and not _secret.is_empty()


## Returns true when guard is disabled, otherwise requires a valid parent token.
func verify_parent_profile(parent: PlayerProfile) -> bool:
	if not is_enabled():
		return true
	if parent == null or not parent.is_parent():
		return false
	if parent.preferences == null:
		return false

	var token_variant: Variant = parent.preferences.get("role_token", null)
	if not (token_variant is RoleToken):
		return false
	var token: RoleToken = token_variant

	if token.profile_id != parent.profile_id:
		return false
	if not token.is_parent_token():
		return false
	if token.is_expired(_clock.now_iso()):
		return false

	return token.verify(_secret)

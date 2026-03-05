## Value object representing a cryptographically verified role token.
## Proves a player's role (KID/PARENT) for defense-in-depth beyond
## simple is_parent()/is_kid() logic checks. Uses HMAC-SHA256.
class_name RoleToken
extends RefCounted

var profile_id: String
var role: PlayerProfile.Role
var issued_at: String   # ISO 8601
var expires_at: String  # ISO 8601
var token_hash: String  # HMAC-SHA256 hex digest


func _init(
	p_profile_id: String = "",
	p_role: PlayerProfile.Role = PlayerProfile.Role.KID,
	p_issued_at: String = "",
	p_expires_at: String = "",
	p_token_hash: String = ""
) -> void:
	profile_id = p_profile_id
	role = p_role
	issued_at = p_issued_at
	expires_at = p_expires_at
	token_hash = p_token_hash


## Issues a new RoleToken for the given profile, valid for duration_minutes.
static func issue(
	profile: PlayerProfile,
	clock: ClockPort,
	secret: PackedByteArray,
	duration_minutes: int = 60
) -> RoleToken:
	if profile == null or clock == null:
		return null
	if secret.is_empty():
		return null

	var now_iso := clock.now_iso()
	var now_msec := clock.now_msec()
	var expires_msec := now_msec + (duration_minutes * 60 * 1000)

	# Build expiry ISO string from msec offset
	var expires_iso := _msec_to_approximate_iso(now_iso, duration_minutes)

	var role_str := "KID" if profile.role == PlayerProfile.Role.KID else "PARENT"
	var token_payload := "%s|%s|%s|%s" % [
		profile.profile_id, role_str, now_iso, expires_iso
	]

	var hmac_hex := _compute_hmac_hex(token_payload.to_utf8_buffer(), secret)

	return RoleToken.new(
		profile.profile_id,
		profile.role,
		now_iso,
		expires_iso,
		hmac_hex
	)


## Verifies the token's HMAC matches the expected value.
func verify(secret: PackedByteArray) -> bool:
	if token_hash.strip_edges().is_empty():
		return false
	if secret.is_empty():
		return false

	var role_str := "KID" if role == PlayerProfile.Role.KID else "PARENT"
	var token_payload := "%s|%s|%s|%s" % [
		profile_id, role_str, issued_at, expires_at
	]

	var expected := _compute_hmac_hex(token_payload.to_utf8_buffer(), secret)
	return _constant_time_compare(expected, token_hash)


## Checks if the token has expired based on the given ISO timestamp.
func is_expired(now_iso: String) -> bool:
	if expires_at.strip_edges().is_empty():
		return true
	# Simple lexicographic comparison works for ISO 8601 timestamps
	return now_iso > expires_at


func is_parent_token() -> bool:
	return role == PlayerProfile.Role.PARENT


func is_kid_token() -> bool:
	return role == PlayerProfile.Role.KID


## Builds an approximate ISO expiry by adding minutes to the hour/minute fields.
## This is a simplified approach — sufficient for token expiry comparison.
static func _msec_to_approximate_iso(base_iso: String, add_minutes: int) -> String:
	# Parse HH:MM from ISO string and add minutes
	if base_iso.length() < 16:
		return base_iso
	var date_part := base_iso.substr(0, 11)  # "2026-03-02T"
	var hour := base_iso.substr(11, 2).to_int()
	var minute := base_iso.substr(14, 2).to_int()
	var suffix := base_iso.substr(16)  # ":SSZ" or similar

	minute += add_minutes
	hour += minute / 60
	minute = minute % 60
	hour = hour % 24  # Wrap at midnight (simplified)

	return "%s%02d:%02d%s" % [date_part, hour, minute, suffix]


static func _compute_hmac_hex(
	data: PackedByteArray,
	key: PackedByteArray
) -> String:
	var ctx := HMACContext.new()
	var err := ctx.start(HashingContext.HASH_SHA256, key)
	if err != OK:
		return ""
	err = ctx.update(data)
	if err != OK:
		return ""
	return ctx.finish().hex_encode()


static func _constant_time_compare(a: String, b: String) -> bool:
	if a.length() != b.length():
		return false
	var result: int = 0
	for i in range(a.length()):
		result = result | (a.unicode_at(i) ^ b.unicode_at(i))
	return result == 0

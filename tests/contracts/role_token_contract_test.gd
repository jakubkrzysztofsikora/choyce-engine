class_name RoleTokenContractTest
extends PortContractTest


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-02T19:00:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1767438000000 + _tick


func run() -> Dictionary:
	_reset()

	var clock := MockClock.new()
	var secret := "role-token-secret-key-32-bytes!".to_utf8_buffer()
	var wrong_secret := "wrong-secret-key-for-testing!!!".to_utf8_buffer()

	var kid := PlayerProfile.new("kid-1", PlayerProfile.Role.KID)
	var parent := PlayerProfile.new("parent-1", PlayerProfile.Role.PARENT)

	# 1. Issue kid token
	var kid_token := RoleToken.issue(kid, clock, secret, 60)
	_assert_true(kid_token != null, "issue() should return a RoleToken for kid")
	_assert_true(kid_token.profile_id == "kid-1", "Token profile_id should match")
	_assert_true(kid_token.is_kid_token(), "Token should be kid token")
	_assert_true(not kid_token.is_parent_token(), "Token should not be parent token")

	# 2. Issue parent token
	var parent_token := RoleToken.issue(parent, clock, secret, 60)
	_assert_true(parent_token != null, "issue() should return a RoleToken for parent")
	_assert_true(parent_token.is_parent_token(), "Token should be parent token")
	_assert_true(not parent_token.is_kid_token(), "Token should not be kid token")

	# 3. Verify with correct secret
	_assert_true(kid_token.verify(secret), "Kid token should verify with correct secret")
	_assert_true(parent_token.verify(secret), "Parent token should verify with correct secret")

	# 4. Verify fails with wrong secret
	_assert_true(
		not kid_token.verify(wrong_secret),
		"Token should fail verification with wrong secret"
	)

	# 5. Token is not expired before expiry
	_assert_true(
		not kid_token.is_expired("2026-03-02T19:30:00Z"),
		"Token should not be expired before expiry time"
	)

	# 6. Token is expired after expiry
	_assert_true(
		kid_token.is_expired("2026-03-02T21:00:00Z"),
		"Token should be expired after expiry time"
	)

	# 7. Null profile returns null
	var null_token := RoleToken.issue(null, clock, secret)
	_assert_true(null_token == null, "issue() with null profile should return null")

	# 8. Null clock returns null
	var no_clock_token := RoleToken.issue(kid, null, secret)
	_assert_true(no_clock_token == null, "issue() with null clock should return null")

	# 9. Empty secret returns null
	var no_secret_token := RoleToken.issue(kid, clock, PackedByteArray())
	_assert_true(no_secret_token == null, "issue() with empty secret should return null")

	# 10. Verify fails with empty secret
	_assert_true(
		not kid_token.verify(PackedByteArray()),
		"verify() with empty secret should return false"
	)

	# 11. Tampered profile_id fails verification
	var tampered_token := RoleToken.issue(kid, clock, secret, 60)
	tampered_token.profile_id = "hacker-1"
	_assert_true(
		not tampered_token.verify(secret),
		"Tampered profile_id should fail verification"
	)

	# 12. Tampered role fails verification
	var role_tamper := RoleToken.issue(kid, clock, secret, 60)
	role_tamper.role = PlayerProfile.Role.PARENT
	_assert_true(
		not role_tamper.verify(secret),
		"Tampered role should fail verification"
	)

	# 13. Token hash is non-empty
	_assert_true(
		not kid_token.token_hash.strip_edges().is_empty(),
		"Token hash should not be empty"
	)

	# 14. Empty token hash fails verification
	var empty_hash_token := RoleToken.new("kid-1", PlayerProfile.Role.KID, "", "", "")
	_assert_true(
		not empty_hash_token.verify(secret),
		"Empty token hash should fail verification"
	)

	# 15. Empty expires_at means expired
	var no_expiry := RoleToken.new("kid-1", PlayerProfile.Role.KID, "", "", "somehash")
	_assert_true(
		no_expiry.is_expired("2026-03-02T19:00:00Z"),
		"Empty expires_at should be treated as expired"
	)

	return _build_result("RoleToken")

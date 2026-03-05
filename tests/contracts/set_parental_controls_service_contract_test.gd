class_name SetParentalControlsServiceContractTest
extends PortContractTest


class StubClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-02T18:00:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1767434400000 + _tick


class StubConsent:
	extends IdentityConsentPort

	var _consents: Dictionary = {}

	func has_consent(profile_id: String, consent_type: String) -> bool:
		return _consents.has(profile_id + "|" + consent_type)

	func request_consent(profile_id: String, consent_type: String) -> bool:
		_consents[profile_id + "|" + consent_type] = true
		return true


class StubTelemetry:
	extends TelemetryPort

	var events: Array = []

	func emit_event(event_name: String, properties: Dictionary) -> void:
		events.append({"event_name": event_name, "properties": properties})


func run() -> Dictionary:
	_reset()

	var clock := StubClock.new()
	var consent := StubConsent.new()
	var telemetry := StubTelemetry.new()
	var policy_store := InMemoryParentalPolicyStore.new().setup()
	var event_bus := DomainEventBus.new()

	var service := SetParentalControlsService.new().setup(
		consent, clock, telemetry, policy_store, event_bus
	)

	# 1. Kid cannot set parental controls
	var kid := PlayerProfile.new("kid-1", PlayerProfile.Role.KID)
	var kid_result := service.execute(kid, {"ai_access": "disabled"})
	_assert_true(not kid_result, "Kid should be rejected from setting controls")

	# 2. Null profile is rejected
	var null_result := service.execute(null, {"ai_access": "disabled"})
	_assert_true(not null_result, "Null profile should be rejected")

	# 3. Invalid setting key is rejected
	var parent := PlayerProfile.new("parent-1", PlayerProfile.Role.PARENT)
	var bad_key := service.execute(parent, {"invalid_key": "value"})
	_assert_true(not bad_key, "Invalid setting key should be rejected")

	# 4. Parent can set AI access
	var ai_result := service.execute(parent, {"ai_access": "disabled"})
	_assert_true(ai_result, "Parent should succeed setting ai_access")

	var loaded := policy_store.load_policy("parent-1")
	_assert_true(loaded != null, "Policy should be persisted after execute")
	_assert_true(
		loaded.is_ai_disabled(),
		"Policy should reflect ai_access=disabled"
	)

	# 5. Parent can set playtime limits
	var playtime := service.execute(parent, {
		"playtime_limit": {"daily": 90, "session": 25},
	})
	_assert_true(playtime, "Parent should succeed setting playtime")

	var pt_loaded := policy_store.load_policy("parent-1")
	_assert_true(
		pt_loaded.daily_playtime_limit_minutes == 90,
		"Daily limit should be 90 after update"
	)
	_assert_true(
		pt_loaded.session_playtime_limit_minutes == 25,
		"Session limit should be 25 after update"
	)

	# 6. Parent can set sharing + cloud sync
	var sharing := service.execute(parent, {
		"sharing_permissions": true,
		"cloud_sync_consent": true,
	})
	_assert_true(sharing, "Parent should succeed setting sharing + cloud")

	var shared := policy_store.load_policy("parent-1")
	_assert_true(shared.sharing_allowed, "Sharing should be enabled")
	_assert_true(shared.cloud_sync_consent, "Cloud sync should be enabled")

	# 7. Event bus receives ParentalPolicyUpdatedEvent
	var history := event_bus.get_history("ParentalPolicyUpdated")
	_assert_true(
		history.size() >= 1,
		"At least one ParentalPolicyUpdatedEvent should be emitted"
	)

	# 8. Telemetry records events
	_assert_true(
		telemetry.events.size() >= 1,
		"Telemetry should record parental_controls_updated events"
	)

	# 9. Consent port receives consent entries
	_assert_true(
		consent.has_consent("parent-1", "parental_control_ai_access"),
		"Consent should be recorded for ai_access"
	)

	# 10. Service works without optional policy_store and event_bus
	var minimal := SetParentalControlsService.new().setup(
		consent, clock, telemetry
	)
	var minimal_result := minimal.execute(parent, {"language_override": true})
	_assert_true(minimal_result, "Service should work without policy_store/event_bus")

	# 11. Previous policy is preserved for unchanged fields
	var new_parent := PlayerProfile.new("parent-new", PlayerProfile.Role.PARENT)
	service.execute(new_parent, {"ai_access": "full"})
	var initial := policy_store.load_policy("parent-new")
	_assert_true(
		initial.daily_playtime_limit_minutes == ParentalControlPolicy.DEFAULT_DAILY_LIMIT_MINUTES,
		"Unchanged fields should keep defaults"
	)
	_assert_true(
		initial.is_ai_full(),
		"Changed field should reflect new value"
	)

	# 12. Optional role-token guard blocks parent mutation without valid token.
	var token_secret := "role-token-signing-key-32-bytes!!!".to_utf8_buffer()
	var guard := RoleTokenGuard.new().setup(clock, token_secret)
	var guarded_service := SetParentalControlsService.new().setup(
		consent, clock, telemetry, policy_store, event_bus, guard
	)
	var guarded_parent := PlayerProfile.new("parent-guarded", PlayerProfile.Role.PARENT)

	_assert_false(
		guarded_service.execute(guarded_parent, {"ai_access": "disabled"}),
		"Guarded service should reject parent changes without role token"
	)

	var kid_for_token := PlayerProfile.new("kid-token", PlayerProfile.Role.KID)
	guarded_parent.preferences["role_token"] = RoleToken.issue(kid_for_token, clock, token_secret, 60)
	_assert_false(
		guarded_service.execute(guarded_parent, {"ai_access": "disabled"}),
		"Guarded service should reject mismatched role token"
	)

	guarded_parent.preferences["role_token"] = RoleToken.issue(guarded_parent, clock, token_secret, 60)
	_assert_true(
		guarded_service.execute(guarded_parent, {"ai_access": "disabled"}),
		"Guarded service should accept valid parent role token"
	)

	return _build_result("SetParentalControlsService")

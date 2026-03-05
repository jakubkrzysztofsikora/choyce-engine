class_name InMemoryParentalPolicyStoreAdapterContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var store := InMemoryParentalPolicyStore.new().setup()

	# 1. Empty store returns null
	var loaded := store.load_policy("parent-1")
	_assert_null(loaded, "Empty store returns null")

	# 2. Save and load round-trip
	var policy := ParentalControlPolicy.new(
		120, 45,
		ParentalControlPolicy.AIAccessLevel.CREATIVE_ONLY,
		true, false, true
	)
	var saved := store.save_policy("parent-1", policy)
	_assert_true(saved, "Save should succeed")

	var retrieved := store.load_policy("parent-1")
	_assert_true(retrieved != null, "Load after save should return policy")
	_assert_true(
		retrieved.daily_playtime_limit_minutes == 120,
		"Daily limit should be 120"
	)
	_assert_true(
		retrieved.session_playtime_limit_minutes == 45,
		"Session limit should be 45"
	)
	_assert_true(
		retrieved.ai_access == ParentalControlPolicy.AIAccessLevel.CREATIVE_ONLY,
		"AI access should be CREATIVE_ONLY"
	)
	_assert_true(retrieved.sharing_allowed, "Sharing should be allowed")
	_assert_true(not retrieved.language_override_allowed, "Language override should be off")
	_assert_true(retrieved.cloud_sync_consent, "Cloud sync should be on")

	# 3. Overwrite policy
	var updated := ParentalControlPolicy.new(
		0, 0,
		ParentalControlPolicy.AIAccessLevel.DISABLED,
		false, false, false
	)
	store.save_policy("parent-1", updated)
	var reloaded := store.load_policy("parent-1")
	_assert_true(
		reloaded.ai_access == ParentalControlPolicy.AIAccessLevel.DISABLED,
		"Overwritten policy should reflect new AI access"
	)
	_assert_true(
		reloaded.daily_playtime_limit_minutes == 0,
		"Overwritten policy should have 0 daily limit"
	)

	# 4. Separate parents have separate policies
	var policy_b := ParentalControlPolicy.new(
		30, 15,
		ParentalControlPolicy.AIAccessLevel.FULL,
		true, true, false
	)
	store.save_policy("parent-2", policy_b)
	var loaded_a := store.load_policy("parent-1")
	var loaded_b := store.load_policy("parent-2")
	_assert_true(
		loaded_a.ai_access == ParentalControlPolicy.AIAccessLevel.DISABLED,
		"Parent-1 policy should be independent"
	)
	_assert_true(
		loaded_b.ai_access == ParentalControlPolicy.AIAccessLevel.FULL,
		"Parent-2 policy should be independent"
	)

	# 5. Reject empty parent_id
	var bad_save := store.save_policy("", policy)
	_assert_true(not bad_save, "Empty parent_id should be rejected")

	# 6. Reject null policy
	var null_save := store.save_policy("parent-3", null)
	_assert_true(not null_save, "Null policy should be rejected")

	# 7. Load non-existent parent returns null
	var missing := store.load_policy("non-existent")
	_assert_null(missing, "Non-existent parent returns null")

	return _build_result("InMemoryParentalPolicyStoreAdapter")

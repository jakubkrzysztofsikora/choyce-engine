## Tests for EncryptedParentalPolicyStore deny-all failsafe path.
##
## MUST-1  Round-trip with correct key: load_policy returns saved policy (regression guard)
## MUST-2  Wrong key: load_policy returns deny-all policy (not null, not original policy)
## MUST-3  Wrong key: load_policy emits ParentalPolicyDecryptionFailedEvent on the bus
## MUST-4  Deny-all policy has AI disabled and no sharing (most-restrictive values)
## MUST-5  Deny-all factory method: ParentalControlPolicy.deny_all() returns restrictive policy
## MUST-6  Correct-key load does NOT emit decryption-failed event
## MUST-7  Invalid parent_id (empty string): load_policy returns deny-all (never null)
## MUST-8  Store not ready (setup not called): load_policy returns deny-all (never null)
## MUST-9  New profile (no file on disk): load_policy returns deny-all (never null)
## MUST-10 Corrupt/wrong-key file: load_policy returns deny-all AND emits ParentalPolicyDecryptionFailedEvent
## MUST-11 Valid encrypted file: load_policy returns the stored policy (sanity)
extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var checks := 0

	const TEST_DIR := "user://test_encrypted_policy_deny_all"
	_cleanup(TEST_DIR)

	var key_a := "0123456789ABCDEF0123456789ABCDEF".to_utf8_buffer()  # 32 bytes
	var key_b := "FEDCBA9876543210FEDCBA9876543210".to_utf8_buffer()  # different key

	var storage := LocalEncryptedStorage.new().setup()
	var event_bus_a := DomainEventBus.new()
	var store_a := EncryptedParentalPolicyStore.new().setup(storage, key_a, TEST_DIR, event_bus_a)

	var policy := ParentalControlPolicy.new(
		60, 30,
		ParentalControlPolicy.AIAccessLevel.FULL,
		true, true, true
	)

	# ── MUST-1: correct key round-trip ────────────────────────────────────────
	checks += 1
	if not store_a.save_policy("parent-1", policy):
		failures.append("MUST-1a: save_policy must succeed with valid key")

	var loaded_ok := store_a.load_policy("parent-1")
	checks += 1
	if loaded_ok == null:
		failures.append("MUST-1b: load_policy with correct key must not return null")
	elif not loaded_ok.equals(policy):
		failures.append("MUST-1c: load_policy with correct key must return matching policy")

	# ── MUST-6: correct key does NOT emit decryption-failed event ────────────
	var history_ok := event_bus_a.get_history("ParentalPolicyDecryptionFailed")
	checks += 1
	if history_ok.size() != 0:
		failures.append("MUST-6: correct-key load must not emit ParentalPolicyDecryptionFailedEvent")

	# ── MUST-2: wrong key returns deny-all (not null, not original) ──────────
	var event_bus_b := DomainEventBus.new()
	var store_b := EncryptedParentalPolicyStore.new().setup(storage, key_b, TEST_DIR, event_bus_b)

	var loaded_bad := store_b.load_policy("parent-1")
	checks += 1
	if loaded_bad == null:
		failures.append("MUST-2a: wrong-key load_policy must return deny-all (not null)")
	elif loaded_bad.equals(policy):
		failures.append("MUST-2b: wrong-key load_policy must NOT return original policy")

	# ── MUST-3: wrong key emits ParentalPolicyDecryptionFailedEvent ──────────
	var history_bad := event_bus_b.get_history("ParentalPolicyDecryptionFailed")
	checks += 1
	if history_bad.size() == 0:
		failures.append("MUST-3a: wrong-key load_policy must emit ParentalPolicyDecryptionFailedEvent")
	else:
		var evt = history_bad[0]
		checks += 1
		if not (evt is ParentalPolicyDecryptionFailedEvent):
			failures.append("MUST-3b: emitted event must be ParentalPolicyDecryptionFailedEvent")
		else:
			checks += 1
			if evt.parent_id != "parent-1":
				failures.append("MUST-3c: event.parent_id must be 'parent-1', got '%s'" % evt.parent_id)
			checks += 1
			if evt.failure_reason.is_empty():
				failures.append("MUST-3d: event.failure_reason must not be empty")

	# ── MUST-4: deny-all from wrong key has AI disabled + no sharing ─────────
	if loaded_bad != null:
		checks += 1
		if loaded_bad.ai_access != ParentalControlPolicy.AIAccessLevel.DISABLED:
			failures.append("MUST-4a: deny-all policy must have ai_access = DISABLED")
		checks += 1
		if loaded_bad.sharing_allowed != false:
			failures.append("MUST-4b: deny-all policy must have sharing_allowed = false")
		checks += 1
		if loaded_bad.cloud_sync_consent != false:
			failures.append("MUST-4c: deny-all policy must have cloud_sync_consent = false")

	# ── MUST-5: ParentalControlPolicy.deny_all() static factory ──────────────
	var deny := ParentalControlPolicy.deny_all()
	checks += 1
	if deny == null:
		failures.append("MUST-5a: deny_all() must not return null")
	else:
		checks += 1
		if deny.ai_access != ParentalControlPolicy.AIAccessLevel.DISABLED:
			failures.append("MUST-5b: deny_all() ai_access must be DISABLED")
		checks += 1
		if deny.sharing_allowed != false:
			failures.append("MUST-5c: deny_all() sharing_allowed must be false")
		checks += 1
		if deny.cloud_sync_consent != false:
			failures.append("MUST-5d: deny_all() cloud_sync_consent must be false")
		checks += 1
		if deny.daily_playtime_limit_minutes == 0:
			failures.append("MUST-5e: deny_all() daily_playtime_limit must be > 0 (0 = unlimited)")
		checks += 1
		if deny.session_playtime_limit_minutes == 0:
			failures.append("MUST-5f: deny_all() session_playtime_limit must be > 0 (0 = unlimited)")

	# ── MUST-7: invalid parent_id (empty string) returns deny-all ────────────
	var result_invalid := store_a.load_policy("")
	checks += 1
	if result_invalid == null:
		failures.append("MUST-7a: load_policy('') must return deny-all, not null")
	else:
		checks += 1
		if result_invalid.ai_access != ParentalControlPolicy.AIAccessLevel.DISABLED:
			failures.append("MUST-7b: deny-all from invalid parent_id must have ai_access = DISABLED")

	# ── MUST-8: store not ready (no setup) returns deny-all ──────────────────
	var unready_store := EncryptedParentalPolicyStore.new()
	var result_unready := unready_store.load_policy("parent-99")
	checks += 1
	if result_unready == null:
		failures.append("MUST-8a: load_policy on unready store must return deny-all, not null")
	else:
		checks += 1
		if result_unready.ai_access != ParentalControlPolicy.AIAccessLevel.DISABLED:
			failures.append("MUST-8b: deny-all from unready store must have ai_access = DISABLED")

	# ── MUST-9: new profile (no file on disk) returns deny-all ───────────────
	var result_new_profile := store_a.load_policy("parent-new-never-saved")
	checks += 1
	if result_new_profile == null:
		failures.append("MUST-9a: load_policy for unknown parent must return deny-all, not null")
	else:
		checks += 1
		if result_new_profile.ai_access != ParentalControlPolicy.AIAccessLevel.DISABLED:
			failures.append("MUST-9b: deny-all for new profile must have ai_access = DISABLED")
		checks += 1
		if result_new_profile.sharing_allowed != false:
			failures.append("MUST-9c: deny-all for new profile must have sharing_allowed = false")

	# ── MUST-10: corrupt/wrong-key file returns deny-all + emits event ───────
	var event_bus_c := DomainEventBus.new()
	var store_c := EncryptedParentalPolicyStore.new().setup(storage, key_b, TEST_DIR, event_bus_c)
	# parent-1 was saved with key_a, store_c uses key_b — decryption will fail.
	var result_corrupt := store_c.load_policy("parent-1")
	checks += 1
	if result_corrupt == null:
		failures.append("MUST-10a: corrupt/wrong-key load must return deny-all, not null")
	else:
		checks += 1
		if result_corrupt.ai_access != ParentalControlPolicy.AIAccessLevel.DISABLED:
			failures.append("MUST-10b: deny-all from corrupt file must have ai_access = DISABLED")
	var history_c := event_bus_c.get_history("ParentalPolicyDecryptionFailed")
	checks += 1
	if history_c.size() == 0:
		failures.append("MUST-10c: corrupt/wrong-key load must emit ParentalPolicyDecryptionFailedEvent")

	# ── MUST-11: valid encrypted file returns stored policy (sanity) ──────────
	var result_valid := store_a.load_policy("parent-1")
	checks += 1
	if result_valid == null:
		failures.append("MUST-11a: valid encrypted load must not return null")
	elif not result_valid.equals(policy):
		failures.append("MUST-11b: valid encrypted load must return the stored policy")

	_cleanup(TEST_DIR)

	if failures.is_empty():
		print("[PASS] EncryptedParentalPolicyStoreDenyAll (%d checks)" % checks)
		quit(0)
	else:
		print("[FAIL] EncryptedParentalPolicyStoreDenyAll")
		for item in failures:
			print("  - %s" % item)
		quit(1)


func _cleanup(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			DirAccess.remove_absolute(absolute + "/" + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute)

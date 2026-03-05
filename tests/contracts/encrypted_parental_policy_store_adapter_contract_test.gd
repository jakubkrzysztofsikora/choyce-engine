class_name EncryptedParentalPolicyStoreAdapterContractTest
extends PortContractTest

const TEST_ROOT := "user://contract_tests/task036_parent_policy_vault"


func run() -> Dictionary:
	_reset()
	_cleanup_user_path(TEST_ROOT)

	var encrypted_storage := LocalEncryptedStorage.new().setup()
	var key := "0123456789ABCDEF0123456789ABCDEF".to_utf8_buffer()
	var store := EncryptedParentalPolicyStore.new().setup(
		encrypted_storage,
		key,
		TEST_ROOT
	)

	var policy := ParentalControlPolicy.new(
		90,
		25,
		ParentalControlPolicy.AIAccessLevel.DISABLED,
		false,
		true,
		true
	)

	_assert_true(
		store.save_policy("parent-1", policy),
		"save_policy should persist encrypted parent policy"
	)

	var expected_path := "%s/%s.policy.enc" % [TEST_ROOT, "parent-1"]
	_assert_true(
		FileAccess.file_exists(expected_path),
		"Encrypted policy file should be created"
	)

	var loaded := store.load_policy("parent-1")
	_assert_true(loaded != null, "load_policy should return persisted policy")
	if loaded != null:
		_assert_true(
			loaded.equals(policy),
			"Loaded policy should match persisted values"
		)

	var wrong_key_store := EncryptedParentalPolicyStore.new().setup(
		encrypted_storage,
		"FEDCBA9876543210FEDCBA9876543210".to_utf8_buffer(),
		TEST_ROOT
	)
	_assert_null(
		wrong_key_store.load_policy("parent-1"),
		"Wrong key should not decrypt parent policy"
	)

	var short_key_store := EncryptedParentalPolicyStore.new().setup(
		encrypted_storage,
		"short-key".to_utf8_buffer(),
		TEST_ROOT
	)
	_assert_false(
		short_key_store.save_policy("parent-2", policy),
		"save_policy should reject non-32-byte encryption key"
	)

	_assert_false(
		store.save_policy("", policy),
		"save_policy should reject empty parent id"
	)
	_assert_null(
		store.load_policy(""),
		"load_policy should return null for empty parent id"
	)

	_cleanup_user_path(TEST_ROOT)
	return _build_result("EncryptedParentalPolicyStoreAdapter")


func _cleanup_user_path(path: String) -> void:
	_remove_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _remove_dir_recursive_absolute(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue

		var child_path := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			_remove_dir_recursive_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()

	DirAccess.remove_absolute(path)

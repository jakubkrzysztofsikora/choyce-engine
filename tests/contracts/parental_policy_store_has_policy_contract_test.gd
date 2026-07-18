## Contract: ParentalPolicyStorePort.has_policy(parent_id) lets callers
## distinguish "brand-new profile, nothing stored" from "a policy exists"
## WITHOUT collapsing a tamper/deny-all read into the same signal as absence.
## Play session policy resolution needs this to apply the friendly first-run
## default (combat on) to genuinely-new kids while still honoring a stored
## (or deny-all-on-tamper) policy for everyone else.
class_name ParentalPolicyStoreHasPolicyContractTest
extends PortContractTest

const TEST_ROOT := "user://contract_tests/has_policy_vault"


func run() -> Dictionary:
	_reset()
	_cleanup_user_path(TEST_ROOT)

	# Port default surface
	var port := ParentalPolicyStorePort.new()
	_assert_has_method(port, "has_policy")
	_assert_false(port.has_policy("parent-1"), "Default has_policy")

	# InMemory adapter: absent → false, present → true
	var mem := InMemoryParentalPolicyStore.new().setup()
	_assert_true(not mem.has_policy("kid-1"), "InMemory: absent profile has no policy")
	mem.save_policy("kid-1", ParentalControlPolicy.new())
	_assert_true(mem.has_policy("kid-1"), "InMemory: saved profile has a policy")
	_assert_true(not mem.has_policy(""), "InMemory: empty id has no policy")

	# Encrypted adapter: no file on disk → false (brand-new kid)
	var storage := LocalEncryptedStorage.new().setup()
	var key := "0123456789ABCDEF0123456789ABCDEF".to_utf8_buffer()
	var enc := EncryptedParentalPolicyStore.new().setup(storage, key, TEST_ROOT)
	_assert_true(not enc.has_policy("kid-1"), "Encrypted: brand-new kid has no policy file")

	# After a save the file exists → true
	_assert_true(enc.save_policy("kid-1", ParentalControlPolicy.new()), "save should persist")
	_assert_true(enc.has_policy("kid-1"), "Encrypted: saved kid now has a policy")

	# Tampered/undecryptable file still counts as "present" — a policy exists,
	# resolution must honor deny-all rather than silently grant first-run combat.
	var wrong_key_store := EncryptedParentalPolicyStore.new().setup(
		storage, "FEDCBA9876543210FEDCBA9876543210".to_utf8_buffer(), TEST_ROOT
	)
	_assert_true(
		wrong_key_store.has_policy("kid-1"),
		"Encrypted: a file exists → has_policy true even under wrong key (deny-all, not first-run)"
	)

	# Invalid/empty id → false, never a crash
	_assert_true(not enc.has_policy(""), "Encrypted: empty id has no policy")

	_cleanup_user_path(TEST_ROOT)
	return _build_result("ParentalPolicyStorePort.has_policy")


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

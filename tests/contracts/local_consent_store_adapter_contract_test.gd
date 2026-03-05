class_name LocalConsentStoreAdapterContractTest
extends PortContractTest

const TEST_FILE := "user://contract_tests/task007_consent/consents.json"


func run() -> Dictionary:
	_reset()
	_cleanup_user_path("user://contract_tests/task007_consent")

	var store := LocalConsentStore.new(TEST_FILE)
	_assert_has_method(store, "has_consent")
	_assert_has_method(store, "request_consent")

	_assert_false(
		store.has_consent("profile_kid_1", "cloud_sync"),
		"LocalConsentStore.has_consent() should default to false"
	)

	var granted := store.request_consent("profile_kid_1", "cloud_sync")
	_assert_true(granted, "LocalConsentStore.request_consent() should persist consent")

	_assert_true(
		store.has_consent("profile_kid_1", "cloud_sync"),
		"Granted consent should be readable immediately"
	)

	var reopened := LocalConsentStore.new(TEST_FILE)
	_assert_true(
		reopened.has_consent("profile_kid_1", "cloud_sync"),
		"Granted consent should persist to disk"
	)

	_assert_false(
		store.request_consent("", "cloud_sync"),
		"Empty profile should be rejected"
	)
	_assert_false(
		store.has_consent("", "cloud_sync"),
		"Empty profile should never be treated as consented"
	)

	_assert_true(FileAccess.file_exists(TEST_FILE), "Consent file should exist on disk")

	_cleanup_user_path("user://contract_tests/task007_consent")
	return _build_result("LocalConsentStoreAdapter")


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

class_name FilesystemAssetRepositoryAdapterContractTest
extends PortContractTest

const TEST_ROOT := "user://contract_tests/task005_asset_repository"


func run() -> Dictionary:
	_reset()
	_cleanup_user_path(TEST_ROOT)

	var repository := FilesystemAssetRepository.new(TEST_ROOT)
	_assert_has_method(repository, "store")
	_assert_has_method(repository, "load")
	_assert_has_method(repository, "exists")

	var bytes := PackedByteArray([1, 2, 3, 4, 255])

	_assert_true(
		repository.store("project_a/clicks/click.bin", bytes),
		"FilesystemAssetRepository.store(project_scoped) should return true"
	)
	_assert_true(
		repository.exists("project_a/clicks/click.bin"),
		"FilesystemAssetRepository.exists(project_scoped) should return true"
	)
	var loaded_scoped := repository.load("project_a/clicks/click.bin")
	_assert_packed_byte_array(loaded_scoped, "FilesystemAssetRepository.load(project_scoped)")
	_assert_true(
		loaded_scoped == bytes,
		"Loaded project-scoped bytes should match stored bytes"
	)

	_assert_true(
		repository.store("project_a:music/theme.bin", bytes),
		"FilesystemAssetRepository.store(colon_format) should return true"
	)
	_assert_true(
		repository.exists("project_a:music/theme.bin"),
		"FilesystemAssetRepository.exists(colon_format) should return true"
	)

	_assert_true(
		repository.store("ambient.bin", bytes),
		"FilesystemAssetRepository.store(shared_asset) should return true"
	)
	_assert_true(
		repository.exists("ambient.bin"),
		"FilesystemAssetRepository.exists(shared_asset) should return true"
	)

	_assert_false(
		repository.store("../escape.bin", bytes),
		"FilesystemAssetRepository.store(path_traversal) should return false"
	)
	_assert_false(
		repository.exists("../escape.bin"),
		"FilesystemAssetRepository.exists(path_traversal) should return false"
	)

	var missing := repository.load("project_a/missing.bin")
	_assert_packed_byte_array(missing, "FilesystemAssetRepository.load(missing)")
	_assert_true(
		missing.is_empty(),
		"Loading missing asset should return empty PackedByteArray"
	)

	_cleanup_user_path(TEST_ROOT)
	return _build_result("FilesystemAssetRepositoryAdapter")


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

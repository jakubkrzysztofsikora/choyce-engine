class_name LocalEncryptedStorageAdapterContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()

	var store := LocalEncryptedStorage.new().setup()
	var key := "0123456789ABCDEF0123456789ABCDEF".to_utf8_buffer()  # exactly 32 bytes
	var wrong_key := "FEDCBA9876543210FEDCBA9876543210".to_utf8_buffer()  # exactly 32 bytes
	var test_path := "user://test_encrypted_storage/test_data.enc"
	var test_path2 := "user://test_encrypted_storage/test_data2.enc"

	# 1. Write + read round-trip
	var original := "Cześć! To są tajne dane rodzica.".to_utf8_buffer()
	var write_ok := store.write_encrypted(test_path, original, key)
	_assert_true(write_ok, "write_encrypted should succeed")

	var read_back := store.read_encrypted(test_path, key)
	_assert_true(
		read_back.get_string_from_utf8() == original.get_string_from_utf8(),
		"Decrypted data should match original"
	)

	# 2. has_encrypted returns true after write
	_assert_true(store.has_encrypted(test_path), "has_encrypted should return true after write")

	# 3. has_encrypted returns false for missing file
	_assert_true(
		not store.has_encrypted("user://test_encrypted_storage/nonexistent.enc"),
		"has_encrypted should return false for missing file"
	)

	# 4. Wrong key fails decryption (HMAC mismatch)
	var wrong_result := store.read_encrypted(test_path, wrong_key)
	_assert_true(
		wrong_result.is_empty(),
		"Reading with wrong key should return empty (HMAC failure)"
	)

	# 5. Empty path rejected on write
	var empty_write := store.write_encrypted("", original, key)
	_assert_true(not empty_write, "Empty path should be rejected on write")

	# 6. Empty path rejected on read
	var empty_read := store.read_encrypted("", key)
	_assert_true(empty_read.is_empty(), "Empty path should return empty on read")

	# 7. Wrong key size rejected (not 32 bytes)
	var short_key := "short".to_utf8_buffer()
	var short_write := store.write_encrypted(test_path2, original, short_key)
	_assert_true(not short_write, "Non-32-byte key should be rejected on write")

	var short_read := store.read_encrypted(test_path, short_key)
	_assert_true(short_read.is_empty(), "Non-32-byte key should return empty on read")

	# 8. Two writes produce different IVs (non-deterministic ciphertext)
	var abs_path := ProjectSettings.globalize_path(test_path)
	store.write_encrypted(test_path, original, key)
	var file1 := FileAccess.open(abs_path, FileAccess.READ)
	var data1 := PackedByteArray()
	if file1 != null:
		data1 = file1.get_buffer(file1.get_length())

	store.write_encrypted(test_path, original, key)
	var file2 := FileAccess.open(abs_path, FileAccess.READ)
	var data2 := PackedByteArray()
	if file2 != null:
		data2 = file2.get_buffer(file2.get_length())

	# IVs are the first 16 bytes — they should differ
	if data1.size() >= 16 and data2.size() >= 16:
		var iv1 := data1.slice(0, 16)
		var iv2 := data2.slice(0, 16)
		_assert_true(iv1 != iv2, "IVs should differ between writes (randomized)")
	else:
		_assert_true(false, "Could not read encrypted files for IV comparison")

	# 9. Tampered ciphertext detected
	store.write_encrypted(test_path, original, key)
	var tamper_file := FileAccess.open(abs_path, FileAccess.READ)
	if tamper_file != null:
		var tampered_data := tamper_file.get_buffer(tamper_file.get_length())
		tamper_file = null
		# Flip a bit in the ciphertext (after IV, before HMAC)
		if tampered_data.size() > 20:
			tampered_data[17] = tampered_data[17] ^ 0xFF
		var tamper_write := FileAccess.open(abs_path, FileAccess.WRITE)
		if tamper_write != null:
			tamper_write.store_buffer(tampered_data)
			tamper_write = null  # close
		var tamper_result := store.read_encrypted(test_path, key)
		_assert_true(
			tamper_result.is_empty(),
			"Tampered ciphertext should be detected by HMAC and return empty"
		)
	else:
		_assert_true(false, "Could not open encrypted file for tamper test")

	# 10. Empty data round-trips correctly (PKCS7 pads full block)
	var empty_data := PackedByteArray()
	store.write_encrypted(test_path2, empty_data, key)
	var empty_back := store.read_encrypted(test_path2, key)
	_assert_true(
		empty_back.size() == 0,
		"Empty data should round-trip to empty"
	)

	# 11. Large data round-trip (multi-block)
	var large := PackedByteArray()
	large.resize(1024)
	for i in range(1024):
		large[i] = i % 256
	store.write_encrypted(test_path, large, key)
	var large_back := store.read_encrypted(test_path, key)
	_assert_true(large_back == large, "Large data should round-trip correctly")

	# Cleanup
	_cleanup("user://test_encrypted_storage/")

	return _build_result("LocalEncryptedStorageAdapter")


func _cleanup(dir_path: String) -> void:
	var abs := ProjectSettings.globalize_path(dir_path)
	var dir := DirAccess.open(abs)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(abs)

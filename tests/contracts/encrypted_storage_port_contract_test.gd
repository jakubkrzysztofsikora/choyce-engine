class_name EncryptedStoragePortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()

	var port := EncryptedStoragePort.new()

	# 1. Port has required methods
	_assert_has_method(port, "write_encrypted")
	_assert_has_method(port, "read_encrypted")
	_assert_has_method(port, "has_encrypted")

	# 2. Default write_encrypted returns false
	var key := "32-byte-encryption-key-for-test".to_utf8_buffer()
	var data := "test data".to_utf8_buffer()
	var write_result := port.write_encrypted("test://path", data, key)
	_assert_true(not write_result, "Default write_encrypted should return false")

	# 3. Default read_encrypted returns empty
	var read_result := port.read_encrypted("test://path", key)
	_assert_true(read_result.is_empty(), "Default read_encrypted should return empty")

	# 4. Default has_encrypted returns false
	var has_result := port.has_encrypted("test://path")
	_assert_true(not has_result, "Default has_encrypted should return false")

	return _build_result("EncryptedStoragePort")

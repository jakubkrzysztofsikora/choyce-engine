## Local file-backed encrypted storage adapter.
## File format: [16-byte IV][ciphertext][32-byte HMAC-SHA256 auth tag]
## Uses AES-256-CBC for encryption and HMAC-SHA256 for integrity verification.
class_name LocalEncryptedStorage
extends EncryptedStoragePort

const IV_SIZE: int = 16
const HMAC_SIZE: int = 32
const AES_BLOCK_SIZE: int = 16


func setup() -> LocalEncryptedStorage:
	return self


func write_encrypted(
	path: String,
	data: PackedByteArray,
	key: PackedByteArray
) -> bool:
	if path.strip_edges().is_empty():
		return false
	if key.size() != 32:
		push_error("LocalEncryptedStorage: key must be 32 bytes (AES-256)")
		return false

	_ensure_dir(path.get_base_dir())

	# Generate random IV
	var crypto := Crypto.new()
	var iv := crypto.generate_random_bytes(IV_SIZE)

	# PKCS7 pad the data to AES block size
	var padded := _pkcs7_pad(data)

	# Encrypt with AES-256-CBC
	var aes := AESContext.new()
	var err := aes.start(AESContext.MODE_CBC_ENCRYPT, key, iv)
	if err != OK:
		push_error("LocalEncryptedStorage: AES start failed: %d" % err)
		return false
	var ciphertext := aes.update(padded)
	aes.finish()

	# Compute HMAC-SHA256 over IV + ciphertext for integrity
	var to_auth := PackedByteArray()
	to_auth.append_array(iv)
	to_auth.append_array(ciphertext)
	var auth_tag := _compute_hmac(to_auth, key)

	# Write: [IV][ciphertext][HMAC]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("LocalEncryptedStorage: cannot open for write: %s" % path)
		return false
	file.store_buffer(iv)
	file.store_buffer(ciphertext)
	file.store_buffer(auth_tag)
	return true


func read_encrypted(
	path: String,
	key: PackedByteArray
) -> PackedByteArray:
	if path.strip_edges().is_empty():
		return PackedByteArray()
	if key.size() != 32:
		push_error("LocalEncryptedStorage: key must be 32 bytes (AES-256)")
		return PackedByteArray()

	if not FileAccess.file_exists(path):
		return PackedByteArray()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()

	var file_data := file.get_buffer(file.get_length())
	var min_size := IV_SIZE + AES_BLOCK_SIZE + HMAC_SIZE
	if file_data.size() < min_size:
		push_error("LocalEncryptedStorage: file too small: %s" % path)
		return PackedByteArray()

	# Parse: [IV][ciphertext][HMAC]
	var iv := file_data.slice(0, IV_SIZE)
	var ciphertext := file_data.slice(IV_SIZE, file_data.size() - HMAC_SIZE)
	var stored_hmac := file_data.slice(file_data.size() - HMAC_SIZE)

	# Verify HMAC before decryption (authenticate-then-decrypt)
	var to_auth := PackedByteArray()
	to_auth.append_array(iv)
	to_auth.append_array(ciphertext)
	var expected_hmac := _compute_hmac(to_auth, key)

	if not _constant_time_compare_bytes(expected_hmac, stored_hmac):
		push_error("LocalEncryptedStorage: HMAC verification failed (tampered or wrong key): %s" % path)
		return PackedByteArray()

	# Decrypt with AES-256-CBC
	var aes := AESContext.new()
	var err := aes.start(AESContext.MODE_CBC_DECRYPT, key, iv)
	if err != OK:
		push_error("LocalEncryptedStorage: AES decrypt start failed: %d" % err)
		return PackedByteArray()
	var decrypted := aes.update(ciphertext)
	aes.finish()

	# PKCS7 unpad
	return _pkcs7_unpad(decrypted)


func has_encrypted(path: String) -> bool:
	if path.strip_edges().is_empty():
		return false
	return FileAccess.file_exists(path)


## PKCS7 padding to AES block boundary.
func _pkcs7_pad(data: PackedByteArray) -> PackedByteArray:
	var pad_len := AES_BLOCK_SIZE - (data.size() % AES_BLOCK_SIZE)
	var padded := data.duplicate()
	for i in range(pad_len):
		padded.append(pad_len)
	return padded


## Removes PKCS7 padding. Returns empty on invalid padding.
func _pkcs7_unpad(data: PackedByteArray) -> PackedByteArray:
	if data.is_empty():
		return PackedByteArray()
	var pad_len: int = data[data.size() - 1]
	if pad_len < 1 or pad_len > AES_BLOCK_SIZE:
		push_error("LocalEncryptedStorage: invalid PKCS7 padding")
		return PackedByteArray()
	for i in range(pad_len):
		if data[data.size() - 1 - i] != pad_len:
			push_error("LocalEncryptedStorage: corrupted PKCS7 padding")
			return PackedByteArray()
	return data.slice(0, data.size() - pad_len)


func _compute_hmac(
	data: PackedByteArray,
	key: PackedByteArray
) -> PackedByteArray:
	var ctx := HMACContext.new()
	var err := ctx.start(HashingContext.HASH_SHA256, key)
	if err != OK:
		push_error("LocalEncryptedStorage: HMAC start failed")
		return PackedByteArray()
	err = ctx.update(data)
	if err != OK:
		push_error("LocalEncryptedStorage: HMAC update failed")
		return PackedByteArray()
	return ctx.finish()


func _constant_time_compare_bytes(a: PackedByteArray, b: PackedByteArray) -> bool:
	if a.size() != b.size():
		return false
	var result: int = 0
	for i in range(a.size()):
		result = result | (a[i] ^ b[i])
	return result == 0


func _ensure_dir(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute)

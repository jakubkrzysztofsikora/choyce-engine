## Outbound port for encrypted data persistence.
## Implementations use AES-256-CBC with HMAC authentication to
## encrypt/decrypt data at rest. Used for parent settings vault.
class_name EncryptedStoragePort
extends RefCounted


## Writes encrypted data to the given path using the provided key.
## Returns true on success.
func write_encrypted(
	path: String,
	data: PackedByteArray,
	key: PackedByteArray
) -> bool:
	push_error("EncryptedStoragePort.write_encrypted() not implemented")
	return false


## Reads and decrypts data from the given path using the provided key.
## Returns empty PackedByteArray on failure (missing file, wrong key, tampered).
func read_encrypted(
	path: String,
	key: PackedByteArray
) -> PackedByteArray:
	push_error("EncryptedStoragePort.read_encrypted() not implemented")
	return PackedByteArray()


## Checks if an encrypted file exists at the given path.
func has_encrypted(path: String) -> bool:
	push_error("EncryptedStoragePort.has_encrypted() not implemented")
	return false

## Encrypted at-rest parental policy store adapter.
## Persists ParentalControlPolicy records per parent profile using EncryptedStoragePort.
class_name EncryptedParentalPolicyStore
extends ParentalPolicyStorePort

var _encrypted_storage: EncryptedStoragePort
var _encryption_key: PackedByteArray = PackedByteArray()
var _root_dir: String = "user://parent_policy_vault"


func setup(
	encrypted_storage: EncryptedStoragePort,
	encryption_key: PackedByteArray,
	root_dir: String = "user://parent_policy_vault"
) -> EncryptedParentalPolicyStore:
	_encrypted_storage = encrypted_storage
	_encryption_key = encryption_key
	_root_dir = root_dir
	return self


func save_policy(parent_id: String, policy: ParentalControlPolicy) -> bool:
	if not _is_valid_parent_id(parent_id):
		return false
	if policy == null:
		return false
	if not _is_ready():
		return false

	_ensure_root_dir()
	var payload := JSON.stringify(policy.to_dict())
	if payload.is_empty():
		return false
	return _encrypted_storage.write_encrypted(
		_policy_path(parent_id),
		payload.to_utf8_buffer(),
		_encryption_key
	)


func load_policy(parent_id: String) -> ParentalControlPolicy:
	if not _is_valid_parent_id(parent_id):
		return null
	if not _is_ready():
		return null

	var path := _policy_path(parent_id)
	if not _encrypted_storage.has_encrypted(path):
		return null

	var decrypted := _encrypted_storage.read_encrypted(path, _encryption_key)
	if decrypted.is_empty():
		return null

	var payload := decrypted.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(payload)
	if parsed is Dictionary:
		return ParentalControlPolicy.from_dict(parsed as Dictionary)
	return null


func _is_ready() -> bool:
	return _encrypted_storage != null and _encryption_key.size() == 32


func _is_valid_parent_id(parent_id: String) -> bool:
	var trimmed := parent_id.strip_edges()
	return not trimmed.is_empty()


func _policy_path(parent_id: String) -> String:
	var safe_id := parent_id.strip_edges().replace("/", "_").replace("\\", "_").replace(":", "_")
	return "%s/%s.policy.enc" % [_root_dir, safe_id]


func _ensure_root_dir() -> void:
	var absolute := ProjectSettings.globalize_path(_root_dir)
	if DirAccess.dir_exists_absolute(absolute):
		return
	DirAccess.make_dir_recursive_absolute(absolute)

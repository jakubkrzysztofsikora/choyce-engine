## Encrypted at-rest parental policy store adapter.
## Persists ParentalControlPolicy records per parent profile using EncryptedStoragePort.
##
## Safety contract: on ANY decryption failure (wrong key, HMAC mismatch, file
## corruption, empty payload, parse error) load_policy() MUST:
##   1. Return ParentalControlPolicy.deny_all()  — never null, never throw.
##   2. Emit ParentalPolicyDecryptionFailedEvent on the event bus when one is set.
## This upholds the CLAUDE.md "consent → deny" failsafe rule.
class_name EncryptedParentalPolicyStore
extends ParentalPolicyStorePort

var _encrypted_storage: EncryptedStoragePort
var _encryption_key: PackedByteArray = PackedByteArray()
var _root_dir: String = "user://parent_policy_vault"
## Optional: when set, decryption failures emit ParentalPolicyDecryptionFailedEvent.
var _event_bus: DomainEventBus


func setup(
	encrypted_storage: EncryptedStoragePort,
	encryption_key: PackedByteArray,
	root_dir: String = "user://parent_policy_vault",
	event_bus: DomainEventBus = null
) -> EncryptedParentalPolicyStore:
	_encrypted_storage = encrypted_storage
	_encryption_key = encryption_key
	_root_dir = root_dir
	_event_bus = event_bus
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
		# read_encrypted returns empty on HMAC failure, wrong key, or AES error.
		push_error(
			"EncryptedParentalPolicyStore: decryption failed for parent '%s' — returning deny-all policy" % parent_id
		)
		_emit_decryption_failed(parent_id, "hmac_or_key_mismatch")
		return ParentalControlPolicy.deny_all()

	var payload := decrypted.get_string_from_utf8()
	if payload.is_empty():
		push_error(
			"EncryptedParentalPolicyStore: empty payload after decryption for parent '%s' — returning deny-all policy" % parent_id
		)
		_emit_decryption_failed(parent_id, "empty_payload")
		return ParentalControlPolicy.deny_all()

	var parsed: Variant = JSON.parse_string(payload)
	if not (parsed is Dictionary):
		push_error(
			"EncryptedParentalPolicyStore: JSON parse error for parent '%s' — returning deny-all policy" % parent_id
		)
		_emit_decryption_failed(parent_id, "parse_error")
		return ParentalControlPolicy.deny_all()

	return ParentalControlPolicy.from_dict(parsed as Dictionary)


func _emit_decryption_failed(parent_id: String, reason: String) -> void:
	if _event_bus == null:
		return
	var event := ParentalPolicyDecryptionFailedEvent.new(parent_id, reason)
	_event_bus.emit(event)


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

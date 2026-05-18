## Domain event emitted when EncryptedParentalPolicyStore cannot decrypt a
## stored policy (wrong key, HMAC mismatch, file corruption).
## Triggers deny-all policy fallback per the CLAUDE.md safety rule:
## "consent → deny applies. Decryption failure → deny-all policy."
class_name ParentalPolicyDecryptionFailedEvent
extends DomainEvent

## The parent profile whose policy could not be decrypted.
var parent_id: String
## Short reason code for the failure (e.g. "hmac_mismatch", "empty_payload", "parse_error").
var failure_reason: String


func _init(p_parent_id: String = "", p_failure_reason: String = "", p_actor_id: String = "", p_timestamp: String = "") -> void:
	super._init("ParentalPolicyDecryptionFailed", p_actor_id, p_timestamp)
	parent_id = p_parent_id
	failure_reason = p_failure_reason
	payload = {
		"parent_id": parent_id,
		"failure_reason": failure_reason,
	}

class_name ManifestSignatureContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()

	var key := "manifest-signing-key-32-bytes!!".to_utf8_buffer()
	var other_key := "different-signing-key-32bytes!!".to_utf8_buffer()
	var payload := '{"plugin_id":"test","name":"Test","version":"1.0.0"}'

	# 1. Sign produces a valid signature
	var sig := ManifestSignature.sign(payload, key, "engine", "2026-03-02T19:00:00Z")
	_assert_true(sig != null, "sign() should return a ManifestSignature")
	_assert_true(sig.is_valid(), "Signature should be valid")
	_assert_true(
		not sig.signature_hex.strip_edges().is_empty(),
		"signature_hex should not be empty"
	)
	_assert_true(sig.signer_id == "engine", "signer_id should be 'engine'")
	_assert_true(sig.signed_at == "2026-03-02T19:00:00Z", "signed_at should match")

	# 2. Verify succeeds with correct key
	var verified := ManifestSignature.verify(payload, key, sig)
	_assert_true(verified, "Verify should pass with correct key and payload")

	# 3. Verify fails with wrong key
	var wrong_key_result := ManifestSignature.verify(payload, other_key, sig)
	_assert_true(not wrong_key_result, "Verify should fail with wrong key")

	# 4. Verify fails with tampered payload
	var tampered_payload := payload + " "
	var tamper_result := ManifestSignature.verify(tampered_payload, key, sig)
	_assert_true(not tamper_result, "Verify should fail with tampered payload")

	# 5. Verify fails with null signature
	var null_result := ManifestSignature.verify(payload, key, null)
	_assert_true(not null_result, "Verify should fail with null signature")

	# 6. Verify fails with empty signature
	var empty_sig := ManifestSignature.new("", "engine", "")
	var empty_result := ManifestSignature.verify(payload, key, empty_sig)
	_assert_true(not empty_result, "Verify should fail with empty signature")

	# 7. is_valid() returns false for empty signature
	_assert_true(not empty_sig.is_valid(), "Empty signature should not be valid")

	# 8. to_dict / from_dict round-trip
	var dict := sig.to_dict()
	var restored := ManifestSignature.from_dict(dict)
	_assert_true(restored.signature_hex == sig.signature_hex, "Round-trip signature_hex should match")
	_assert_true(restored.signer_id == sig.signer_id, "Round-trip signer_id should match")
	_assert_true(restored.signed_at == sig.signed_at, "Round-trip signed_at should match")

	# 9. Restored signature still verifies
	var restored_verified := ManifestSignature.verify(payload, key, restored)
	_assert_true(restored_verified, "Restored signature should verify")

	# 10. Deterministic: signing same payload twice yields same hex
	var sig2 := ManifestSignature.sign(payload, key, "engine", "2026-03-02T19:00:01Z")
	_assert_true(
		sig.signature_hex == sig2.signature_hex,
		"Same payload + key should produce same HMAC"
	)

	# 11. Different payloads produce different signatures
	var other_sig := ManifestSignature.sign('{"other":"data"}', key, "engine", "")
	_assert_true(
		sig.signature_hex != other_sig.signature_hex,
		"Different payloads should produce different signatures"
	)

	return _build_result("ManifestSignature")

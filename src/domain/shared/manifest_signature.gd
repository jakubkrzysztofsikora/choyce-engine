## Value object representing a cryptographic signature for plugin manifests.
## Uses HMAC-SHA256 to sign and verify manifest payloads, replacing the
## placeholder "signed:" prefix check from the original PluginSDK.
class_name ManifestSignature
extends RefCounted

var signature_hex: String
var signer_id: String
var signed_at: String  # ISO 8601


func _init(
	p_signature_hex: String = "",
	p_signer_id: String = "",
	p_signed_at: String = ""
) -> void:
	signature_hex = p_signature_hex
	signer_id = p_signer_id
	signed_at = p_signed_at


## Creates a new ManifestSignature by HMAC-SHA256 signing the payload.
static func sign(
	payload_json: String,
	secret_key: PackedByteArray,
	p_signer_id: String = "engine",
	p_signed_at: String = ""
) -> ManifestSignature:
	var hmac_hex := _compute_hmac_hex(payload_json.to_utf8_buffer(), secret_key)
	return ManifestSignature.new(hmac_hex, p_signer_id, p_signed_at)


## Verifies the given signature matches the expected HMAC-SHA256 of the payload.
static func verify(
	payload_json: String,
	secret_key: PackedByteArray,
	signature: ManifestSignature
) -> bool:
	if signature == null:
		return false
	if signature.signature_hex.strip_edges().is_empty():
		return false
	var expected_hex := _compute_hmac_hex(payload_json.to_utf8_buffer(), secret_key)
	return _constant_time_compare(expected_hex, signature.signature_hex)


func is_valid() -> bool:
	return not signature_hex.strip_edges().is_empty()


func to_dict() -> Dictionary:
	return {
		"signature_hex": signature_hex,
		"signer_id": signer_id,
		"signed_at": signed_at,
	}


static func from_dict(data: Dictionary) -> ManifestSignature:
	return ManifestSignature.new(
		str(data.get("signature_hex", "")),
		str(data.get("signer_id", "")),
		str(data.get("signed_at", "")),
	)


## Computes HMAC-SHA256 and returns the hex digest.
static func _compute_hmac_hex(
	data: PackedByteArray,
	key: PackedByteArray
) -> String:
	var ctx := HMACContext.new()
	var err := ctx.start(HashingContext.HASH_SHA256, key)
	if err != OK:
		push_error("ManifestSignature: HMACContext.start() failed: %d" % err)
		return ""
	err = ctx.update(data)
	if err != OK:
		push_error("ManifestSignature: HMACContext.update() failed: %d" % err)
		return ""
	var digest := ctx.finish()
	return digest.hex_encode()


## Constant-time comparison to prevent timing attacks.
static func _constant_time_compare(a: String, b: String) -> bool:
	if a.length() != b.length():
		return false
	var result: int = 0
	for i in range(a.length()):
		result = result | (a.unicode_at(i) ^ b.unicode_at(i))
	return result == 0

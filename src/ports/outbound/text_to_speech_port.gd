## Outbound port contract for text-to-speech generation.
## Adapter implementations can map voice profiles to provider-specific IDs.
class_name TextToSpeechPort
extends RefCounted


func synthesize(text: String, voice_id: String, language: String) -> PackedByteArray:
	push_error("TextToSpeechPort.synthesize() not implemented")
	return PackedByteArray()


## Optional role resolver for adapters with policy-controlled voice presets.
## Default behavior is pass-through.
func resolve_voice_for_role(role: String, _language: String = "") -> String:
	return role


## Metadata required for governance checks (licensing/watermark/attribution).
## Adapters should return {} when unavailable.
func get_last_request_metadata() -> Dictionary:
	return {}

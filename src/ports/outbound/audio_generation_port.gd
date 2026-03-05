## Outbound port contract for AI-generated audio assets.
## Audio output still requires moderation and licensing checks upstream.
class_name AudioGenerationPort
extends RefCounted


func generate_sfx(description: String) -> PackedByteArray:
	push_error("AudioGenerationPort.generate_sfx() not implemented")
	return PackedByteArray()


func generate_music(description: String) -> PackedByteArray:
	push_error("AudioGenerationPort.generate_music() not implemented")
	return PackedByteArray()


## Metadata required for governance checks (licensing/watermark/attribution).
## Adapters should return {} when unavailable.
func get_last_generation_metadata() -> Dictionary:
	return {}

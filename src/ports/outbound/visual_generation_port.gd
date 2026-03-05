## Outbound port contract for AI visual asset generation providers.
## Implementations should return deterministic metadata payloads and raw bytes
## that can be moderated before preview/apply.
class_name VisualGenerationPort
extends RefCounted


## Expected Dictionary shape:
## {
##   "image_bytes": PackedByteArray,
##   "mime_type": String,
##   "provider_asset_id": String,
##   "metadata": Dictionary
## }
func generate_image(prompt: String, style_preset: String, language: String) -> Dictionary:
	push_error("VisualGenerationPort.generate_image() not implemented")
	return {
		"image_bytes": PackedByteArray(),
		"mime_type": "",
		"provider_asset_id": "",
		"metadata": {},
	}

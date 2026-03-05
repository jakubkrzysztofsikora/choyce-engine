## Value object tracking the provenance of an asset or entity.
## Stores whether it was user-created or AI-generated, and links
## to the audit record if applicable.
class_name ProvenanceData
extends RefCounted

enum SourceType {
	HUMAN,      # Created directly by user
	AI_TEXT,    # LLM generated text/script
	AI_VISUAL,  # Generated image/texture/mesh
	AI_AUDIO,   # Generated speech/sfx
	HYBRID      # Human edited AI result
}

var source: SourceType
var generator_model: String
var audit_id: String
var timestamp: int


func _init(
	p_source: SourceType = SourceType.HUMAN,
	p_model: String = "",
	p_audit_id: String = ""
) -> void:
	source = p_source
	generator_model = p_model
	audit_id = p_audit_id
	timestamp = Time.get_unix_time_from_system()


func is_ai_generated() -> bool:
	return source != SourceType.HUMAN

func get_badge_icon_name() -> String:
	match source:
		SourceType.AI_TEXT: return "text_fields"
		SourceType.AI_VISUAL: return "palette"
		SourceType.AI_AUDIO: return "mic"
		SourceType.HYBRID: return "build"
		_: return "person"

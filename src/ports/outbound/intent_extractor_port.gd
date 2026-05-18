## Outbound port contract for intent extraction from transcribed speech.
## Implementations convert raw transcript strings to structured intent tokens
## used for AI orchestration and command dispatch.
class_name IntentExtractorPort
extends RefCounted

func extract_intent(_transcript: String) -> String:
	return ""

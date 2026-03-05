## Inbound port: request a context-aware gameplay hint.
## Uses scaffold strategy: hint level 1 (nudge) → 2 (guidance) → 3 (solution).
## Never reveals full solutions by default.
class_name RequestGameplayHintPort
extends RefCounted


## Returns Dictionary with keys: "hint_text", "hint_level", "quest_id".
func execute(session_id: String, context: Dictionary, actor: PlayerProfile) -> Dictionary:
	push_error("RequestGameplayHintPort.execute() not implemented")
	return {}

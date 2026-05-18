## Pre-filter user prompts for known injection patterns before sending to LLM.
## Detects common prompt-injection tricks with case-insensitive matching
## and basic homoglyph normalization.
class_name PromptInjectionFilter
extends RefCounted

var _patterns: Array[Dictionary] = [
	# English patterns
	{"pattern": "ignore previous instructions", "reason": "instruction_override"},
	{"pattern": "ignore all prior", "reason": "instruction_override"},
	{"pattern": "system prompt:", "reason": "system_leak"},
	{"pattern": "you are now", "reason": "role_override"},
	{"pattern": "disregard", "reason": "instruction_override"},
	{"pattern": "dlsregard", "reason": "instruction_override"},
	{"pattern": "new instructions:", "reason": "instruction_override"},
	# Polish patterns — hard floor of 7 curated phrases (plan §5, no auto-merge)
	{"pattern": "ignoruj poprzednie instrukcje", "reason": "instruction_override"},
	{"pattern": "zignoruj wszystkie", "reason": "instruction_override"},
	{"pattern": "teraz jesteś", "reason": "role_override"},
	{"pattern": "nowe instrukcje:", "reason": "instruction_override"},
	{"pattern": "od teraz", "reason": "instruction_override"},
	{"pattern": "zapomnij", "reason": "instruction_override"},
	{"pattern": "udawaj że", "reason": "role_override"},
	# Diacritic-stripped variants for evasion defence (ś→s, ż→z)
	{"pattern": "teraz jestes", "reason": "role_override"},
	{"pattern": "udawaj ze", "reason": "role_override"},
]


## Checks a prompt for known injection patterns.
## Returns {"clean": bool, "reason": String, "matches": Array[String]}
func check_prompt(text: String) -> Dictionary:
	var normalized := _normalize(text)
	var matches: Array[String] = []
	var reason := ""

	for entry in _patterns:
		var pattern: String = entry["pattern"]
		if normalized.contains(pattern):
			matches.append(pattern)
			if reason.is_empty():
				reason = entry["reason"]

	return {
		"clean": matches.is_empty(),
		"reason": reason,
		"matches": matches,
	}


## Lowercases and applies basic homoglyph normalization.
func _normalize(text: String) -> String:
	var lowered := text.to_lower()
	# Simple homoglyph replacements commonly used in prompt injection
	var normalized := lowered.replace("і", "i")  # Cyrillic і -> Latin i
	normalized = normalized.replace("а", "a")    # Cyrillic а -> Latin a
	normalized = normalized.replace("е", "e")    # Cyrillic е -> Latin e
	normalized = normalized.replace("о", "o")    # Cyrillic о -> Latin o
	normalized = normalized.replace("р", "p")    # Cyrillic р -> Latin p
	normalized = normalized.replace("с", "c")    # Cyrillic с -> Latin c
	normalized = normalized.replace("х", "x")    # Cyrillic х -> Latin x
	normalized = normalized.replace("у", "y")    # Cyrillic у -> Latin y
	return normalized

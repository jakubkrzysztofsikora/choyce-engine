## Polish intent extractor for child speech normalization.
## Converts raw Polish transcription to structured intent for AI orchestration.
class_name PolishIntentExtractor
extends RefCounted

var _age_band: AgeBand

func setup(age_band: AgeBand = null) -> PolishIntentExtractor:
	if age_band == null:
		_age_band = AgeBand.new(AgeBand.Band.CHILD_6_8)
	else:
		_age_band = age_band
	return self

func extract_intent(raw_transcript: String) -> String:
	if raw_transcript == "":
		return ""
	
	# Normalize Polish child speech patterns based on age band
	var normalized := _normalize_polish_child_speech(raw_transcript)
	
	# Extract intent from normalized text
	return _extract_intent_from_text(normalized)

func _normalize_polish_child_speech(text: String) -> String:
	# Common Polish child speech pattern normalizations
	var normalized := text

	# Child pronunciation patterns (use word boundary matching to avoid false positives)
	# Pattern: normalize ending "-sia" to "-się" only in verb contexts
	normalized = _regex_replace(normalized, "(chce|moge|chcę|mogę)\\s*sia", "$1 się")

	# "dzis" -> "dzisiaj" (whole word)
	normalized = _regex_replace(normalized, "\\bdzis\\b", "dzisiaj")

	# Add spaces around common words that kids might run together
	normalized = _regex_replace(normalized, "budowaćsklep", "budować sklep")
	normalized = _regex_replace(normalized, "zrobićdom", "zrobić dom")

	return normalized


func _regex_replace(input: String, pattern: String, replacement: String) -> String:
	var regex := RegEx.new()
	var err := regex.compile(pattern)
	if err != OK:
		return input
	return regex.sub(input, replacement, true)

func _extract_intent_from_text(text: String) -> String:
	# Simple intent extraction based on keywords
	# Includes both infinitive and imperative forms (children use imperatives more)
	var lower_text := text.to_lower()

	# CREATE: infinitives (budować, zrobić) + imperatives (buduj, zbuduj, zrób)
	if lower_text.find("budować") != -1 or lower_text.find("buduj") != -1 or \
	   lower_text.find("zbuduj") != -1 or lower_text.find("zrobić") != -1 or \
	   lower_text.find("zrób") != -1:
		return "CREATE_OBJECT"

	# DELETE: infinitives (usunąć, zburzyć) + imperatives (usuń, zburz)
	elif lower_text.find("usunąć") != -1 or lower_text.find("usuń") != -1 or \
	     lower_text.find("zburzyć") != -1 or lower_text.find("zburz") != -1:
		return "DELETE_OBJECT"

	# MOVE: infinitives (przesunąć, przenieść) + imperatives (przesuń, przenieś)
	elif lower_text.find("przesunąć") != -1 or lower_text.find("przesuń") != -1 or \
	     lower_text.find("przenieść") != -1 or lower_text.find("przenieś") != -1:
		return "MOVE_OBJECT"

	# HELP: infinitives + imperatives
	elif lower_text.find("pomoc") != -1 or lower_text.find("pomocy") != -1 or \
	     lower_text.find("podpowiedź") != -1 or lower_text.find("podpowiedzi") != -1:
		return "REQUEST_HELP"

	# GAME: infinitives (grać, zagrać) + imperatives (graj, zagraj)
	elif lower_text.find("grać") != -1 or lower_text.find("graj") != -1 or \
	     lower_text.find("zagrać") != -1 or lower_text.find("zagraj") != -1:
		return "START_GAME"

	else:
		return "GENERAL_QUERY"

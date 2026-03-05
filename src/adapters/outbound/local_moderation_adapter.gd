## Local rules-based moderation adapter for ModerationPort.
## Enforces text and image safety checks using Polish-first word lists
## with age-band differentiated severity. Defaults to BLOCK for unknown
## failures (fail-closed).
class_name LocalModerationAdapter
extends ModerationPort

var _categories: Dictionary = {}
var _age_overrides: Dictionary = {}
var _image_rules: Dictionary = {}
var _rules_file: String = "res://data/moderation/rules_pl.json"


func setup(
	rules_file: String = "res://data/moderation/rules_pl.json"
) -> LocalModerationAdapter:
	_rules_file = rules_file.strip_edges()
	_load_defaults()
	if not _rules_file.is_empty():
		_load_rules_file()
	return self


func check_text(text: String, age_band: AgeBand) -> ModerationResult:
	if text.strip_edges().is_empty():
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")

	var normalized := text.strip_edges().to_lower()
	var words := _tokenize(normalized)

	# Check age-band specific additional blocks first
	var age_key := _age_band_key(age_band)
	if _age_overrides.has(age_key):
		var override: Dictionary = _age_overrides[age_key]
		var extra_blocked: Array = override.get("additional_blocked", [])
		for blocked_term in extra_blocked:
			var term_str := str(blocked_term)
			if _word_match(words, term_str):
				var alt: String = str(override.get("default_alternative", ""))
				return _blocked_result("age_restricted", alt, term_str)

	# Check each category
	for cat_name in _categories.keys():
		var category: Dictionary = _categories[cat_name]
		var severity: String = str(category.get("severity", "block"))
		var terms: Array = category.get("terms", [])
		var safe_alt: String = str(category.get("safe_alternative", ""))

		for term in terms:
			var term_str := str(term)
			if _word_match(words, term_str):
				if severity == "warn_child" and age_band != null and not age_band.is_child():
					var warn_result := ModerationResult.new(ModerationResult.Verdict.WARN, term_str)
					warn_result.category = str(cat_name)
					warn_result.confidence = 0.8
					warn_result.safe_alternative = safe_alt
					return warn_result
				return _blocked_result(str(cat_name), safe_alt, term_str)

	return ModerationResult.new(ModerationResult.Verdict.PASS, "")


func check_image(image_data: PackedByteArray, _age_band: AgeBand) -> ModerationResult:
	if image_data.is_empty():
		return ModerationResult.new(
			ModerationResult.Verdict.BLOCK,
			"Empty image data"
		)

	var max_size: int = int(_image_rules.get("max_size_bytes", 10485760))
	if image_data.size() > max_size:
		var result := ModerationResult.new(
			ModerationResult.Verdict.BLOCK,
			"Image exceeds maximum size"
		)
		result.category = "size_limit"
		return result

	var formats: Dictionary = _image_rules.get("allowed_formats_magic", {})
	var format_ok := false
	for fmt_name in formats.keys():
		var magic: Array = formats[fmt_name]
		if _check_magic_bytes(image_data, magic):
			format_ok = true
			break

	if not format_ok and not formats.is_empty():
		var result := ModerationResult.new(
			ModerationResult.Verdict.BLOCK,
			"Unrecognized image format"
		)
		result.category = "format"
		return result

	return ModerationResult.new(ModerationResult.Verdict.PASS, "")


func _blocked_result(category: String, safe_alternative: String, reason: String) -> ModerationResult:
	var result := ModerationResult.new(ModerationResult.Verdict.BLOCK, reason)
	result.category = category
	result.confidence = 1.0
	result.safe_alternative = safe_alternative
	return result


func _word_match(words: Array, term: String) -> bool:
	# Whole-word matching to avoid false positives like "obrona" matching "bron"
	for word in words:
		if str(word) == term:
			return true
	return false


func _tokenize(text: String) -> Array:
	var cleaned := text
	for ch in [".", ",", "!", "?", ";", ":", "(", ")", "[", "]", "{", "}", "\"", "'", "-"]:
		cleaned = cleaned.replace(ch, " ")
	var parts := cleaned.split(" ", false)
	var tokens: Array = []
	for part in parts:
		var stripped := part.strip_edges()
		if not stripped.is_empty():
			tokens.append(stripped)
	return tokens


func _age_band_key(age_band: AgeBand) -> String:
	if age_band == null:
		return "CHILD_6_8"
	match age_band.band:
		AgeBand.Band.CHILD_6_8: return "CHILD_6_8"
		AgeBand.Band.CHILD_9_12: return "CHILD_9_12"
		AgeBand.Band.TEEN: return "TEEN"
		AgeBand.Band.PARENT: return "PARENT"
	return "CHILD_6_8"


func _check_magic_bytes(data: PackedByteArray, magic: Array) -> bool:
	if data.size() < magic.size():
		return false
	for i in range(magic.size()):
		if data[i] != int(magic[i]):
			return false
	return true


func _load_defaults() -> void:
	_categories = {
		"violence": {
			"terms": ["zabij", "zabic", "zabijac", "przemoc", "krew", "ranic"],
			"safe_alternative": "Sprobuj stworzyc cos przyjaznego i bezpiecznego.",
			"severity": "block",
		},
		"weapons": {
			"terms": ["bron", "pistolet", "karabin", "bomba", "strzelac"],
			"safe_alternative": "Uzyj bezpiecznych narzedzi do budowania.",
			"severity": "block",
		},
		"drugs": {
			"terms": ["narkotyk", "narkotyki", "alkohol"],
			"safe_alternative": "Wybierz cos zdrowszego dla swojej postaci.",
			"severity": "block",
		},
		"gambling": {
			"terms": ["hazard", "kasyno"],
			"safe_alternative": "Sprobuj stworzyc gre zrecznosciowa zamiast tego.",
			"severity": "block",
		},
		"profanity": {
			"terms": ["cholera", "kurwa"],
			"safe_alternative": "Uzyj milszych slow w swojej grze.",
			"severity": "block",
		},
	}
	_age_overrides = {
		"CHILD_6_8": {
			"additional_blocked": ["straszny", "potwor", "smierc"],
			"default_alternative": "Wybierz cos przyjemniejszego do zabawy!",
		},
	}
	_image_rules = {
		"max_size_bytes": 10485760,
		"allowed_formats_magic": {
			"png": [137, 80, 78, 71],
			"jpg": [255, 216, 255],
		},
	}


func _load_rules_file() -> void:
	if _rules_file.is_empty() or not FileAccess.file_exists(_rules_file):
		return

	var file := FileAccess.open(_rules_file, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return

	var data: Dictionary = parsed

	if data.has("categories") and data["categories"] is Dictionary:
		var cats: Dictionary = data["categories"]
		for cat_name in cats.keys():
			if cats[cat_name] is Dictionary:
				_categories[str(cat_name)] = cats[cat_name]

	if data.has("age_band_overrides") and data["age_band_overrides"] is Dictionary:
		var overrides: Dictionary = data["age_band_overrides"]
		for key in overrides.keys():
			if overrides[key] is Dictionary:
				_age_overrides[str(key)] = overrides[key]

	if data.has("image_rules") and data["image_rules"] is Dictionary:
		_image_rules = data["image_rules"]

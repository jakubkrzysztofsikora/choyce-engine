## Local rules-based moderation adapter for ModerationPort.
## Enforces text and image safety checks using Polish-first word lists
## with age-band differentiated severity. Defaults to BLOCK for unknown
## failures (fail-closed).
##
## Hardened with homoglyph defense: Cyrillic lookalikes and fullwidth
## characters are mapped to ASCII before matching. Polish diacritics
## are stripped so both composed and decomposed forms match the
## ASCII-based word lists.
class_name LocalModerationAdapter
extends ModerationPort

## Maximum number of terms allowed in the flattened lookup dict (Phase 8b cap).
## Exceeding this triggers a warning; lowest-priority categories are dropped.
const MAX_MODERATION_TERMS := 5000

## Priority order for category retention when the term cap is exceeded.
## Categories listed first are kept; those not listed are dropped last.
const CATEGORY_PRIORITY := [
	"violence", "weapons", "drugs", "gambling", "profanity", "photoreal_human"
]

var _categories: Dictionary = {}
var _age_overrides: Dictionary = {}
var _image_rules: Dictionary = {}
var _rules_file: String = "res://data/moderation/rules_pl.json"

## Flat {normalized_term: {category, severity, safe_alt}} dict built at setup().
## Enables O(1) per-word lookup instead of nested category×term scan.
var _term_lookup: Dictionary = {}

## Maps visually similar Unicode characters to their ASCII equivalents.
## Covers Cyrillic homoglyphs and fullwidth Latin letters.
const HOMOGLYPH_MAP := {
	# Cyrillic lookalikes
	"а": "a", "е": "e", "о": "o", "р": "p", "с": "c", "х": "x",
	"і": "i", "ј": "j", "ԛ": "q", "ѕ": "s", "ս": "u", "ν": "v",
	"ω": "w", "у": "y",
	# Fullwidth A-Z
	"Ａ": "A", "Ｂ": "B", "Ｃ": "C", "Ｄ": "D", "Ｅ": "E",
	"Ｆ": "F", "Ｇ": "G", "Ｈ": "H", "Ｉ": "I", "Ｊ": "J",
	"Ｋ": "K", "Ｌ": "L", "Ｍ": "M", "Ｎ": "N", "Ｏ": "O",
	"Ｐ": "P", "Ｑ": "Q", "Ｒ": "R", "Ｓ": "S", "Ｔ": "T",
	"Ｕ": "U", "Ｖ": "V", "Ｗ": "W", "Ｘ": "X", "Ｙ": "Y",
	"Ｚ": "Z",
	# Fullwidth a-z
	"ａ": "a", "ｂ": "b", "ｃ": "c", "ｄ": "d", "ｅ": "e",
	"ｆ": "f", "ｇ": "g", "ｈ": "h", "ｉ": "i", "ｊ": "j",
	"ｋ": "k", "ｌ": "l", "ｍ": "m", "ｎ": "n", "ｏ": "o",
	"ｐ": "p", "ｑ": "q", "ｒ": "r", "ｓ": "s", "ｔ": "t",
	"ｕ": "u", "ｖ": "v", "ｗ": "w", "ｘ": "x", "ｙ": "y",
	"ｚ": "z",
}

## Maps Polish composed characters to their base Latin forms so that
## terms like "zabić" normalize to "zabic" and match the word lists.
const POLISH_DIACRITIC_MAP := {
	"ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n",
	"ó": "o", "ś": "s", "ź": "z", "ż": "z",
}

## Maps common leetspeak digits to their letter lookalikes so that
## terms like "br0n" normalize to "bron" and match the word lists.
const DIGIT_MAP := {
	"0": "o",
	"1": "i",
	"3": "e",
	"4": "a",
	"5": "s",
	"7": "t",
	"8": "b",
}


func setup(
	rules_file: String = "res://data/moderation/rules_pl.json"
) -> LocalModerationAdapter:
	_rules_file = rules_file.strip_edges()
	_load_defaults()
	if not _rules_file.is_empty():
		_load_rules_file()
	_build_term_lookup()
	return self


func check_text(text: String, age_band: AgeBand) -> ModerationResult:
	if text.strip_edges().is_empty():
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")

	var words := _tokenize(text.strip_edges())

	# Check age-band specific additional blocks first (O(N words) scan)
	var age_key := _age_band_key(age_band)
	if _age_overrides.has(age_key):
		var override: Dictionary = _age_overrides[age_key]
		var extra_blocked: Array = override.get("additional_blocked", [])
		# Build a set for O(1) membership test
		var extra_set: Dictionary = {}
		for bt in extra_blocked:
			extra_set[str(bt)] = true
		for word in words:
			var word_str := str(word)
			if extra_set.has(word_str):
				var alt: String = str(override.get("default_alternative", ""))
				return _blocked_result("age_restricted", alt, word_str)

	# O(N words) lookup via flat _term_lookup dict
	for word in words:
		var word_str := str(word)
		if _term_lookup.has(word_str):
			var entry: Dictionary = _term_lookup[word_str]
			var severity: String = str(entry.get("severity", "block"))
			var cat_name: String = str(entry.get("category", ""))
			var safe_alt: String = str(entry.get("safe_alt", ""))
			if severity == "warn_child" and age_band != null and not age_band.is_child():
				var warn_result := ModerationResult.new(ModerationResult.Verdict.WARN, word_str)
				warn_result.category = cat_name
				warn_result.confidence = 0.8
				warn_result.safe_alternative = safe_alt
				return warn_result
			return _blocked_result(cat_name, safe_alt, word_str)

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


## Normalizes text by mapping homoglyphs, stripping Polish diacritics, and
## transliterating leetspeak digits. Uses PackedStringArray accumulator to
## avoid repeated String concatenation (Phase 8b rewrite).
func _normalize_text(text: String) -> String:
	var lowered := text.to_lower()
	var chars := PackedStringArray()
	chars.resize(lowered.length())
	for i in range(lowered.length()):
		var ch := lowered[i]
		if HOMOGLYPH_MAP.has(ch):
			chars[i] = HOMOGLYPH_MAP[ch]
		elif POLISH_DIACRITIC_MAP.has(ch):
			chars[i] = POLISH_DIACRITIC_MAP[ch]
		elif DIGIT_MAP.has(ch):
			chars[i] = DIGIT_MAP[ch]
		else:
			chars[i] = ch
	return "".join(chars)


## Tokenizes text into normalized words using a single-pass split approach
## (Phase 8b rewrite). Replaces 19+ chained .replace() calls with character
## classification during normalize, then String.split().
func _tokenize(text: String) -> Array:
	var normalized := _normalize_text(text)
	# Replace punctuation with spaces in a single pass using character classification.
	# Any character that is not a-z, 0-9, or space becomes a space delimiter.
	var chars := PackedStringArray()
	chars.resize(normalized.length())
	for i in range(normalized.length()):
		var ch := normalized[i]
		var code := ch.unicode_at(0)
		# a-z: 97-122, 0-9: 48-57, space: 32
		if (code >= 97 and code <= 122) or code == 32:
			chars[i] = ch
		elif code >= 48 and code <= 57:
			# Digits 2, 6, 9 are removed (no leet mapping); others already
			# transliterated to letters by _normalize_text.
			chars[i] = " "
		else:
			chars[i] = " "
	var joined := "".join(chars)
	var parts := joined.split(" ", false)
	var tokens: Array = []
	for part in parts:
		if not part.is_empty():
			tokens.append(part)
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
		# Merged from VisualAssetGenerationService.PHOTOREAL_HUMAN_TERMS (Phase 5b).
		# Multi-word originals ("realistic human", "human portrait", "portret czlowieka")
		# are split to their most distinctive single token so that whole-word matching works.
		# "photo-real" hyphen tokenizes to "photo"+"real"; "photoreal" (no hyphen) is the
		# canonical form and is kept as-is.
		"photoreal_human": {
			"terms": [
				"photoreal",
				"fotorealistyczny",
				"selfie",
			],
			"safe_alternative": "Uzyj stylu 'cartoon' i przyjaznej postaci kreskowkowej.",
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


## Builds the flat {normalized_term → {category, severity, safe_alt}} lookup dict.
## Called once at setup() after all categories are loaded. Enforces MAX_MODERATION_TERMS
## cap by dropping lowest-priority categories first (Phase 8b).
func _build_term_lookup() -> void:
	_term_lookup = {}

	# Determine category insertion order: priority list first, then remainder.
	var ordered_cats: Array[String] = []
	for cat in CATEGORY_PRIORITY:
		if _categories.has(cat):
			ordered_cats.append(cat)
	for cat_name in _categories.keys():
		if not ordered_cats.has(str(cat_name)):
			ordered_cats.append(str(cat_name))

	var total := 0
	var truncated := false
	for cat_name in ordered_cats:
		if total >= MAX_MODERATION_TERMS:
			truncated = true
			push_warning(
				"LocalModerationAdapter: term cap %d reached; dropping category '%s'" %
				[MAX_MODERATION_TERMS, cat_name]
			)
			continue
		var category: Dictionary = _categories[cat_name]
		var severity: String = str(category.get("severity", "block"))
		var safe_alt: String = str(category.get("safe_alternative", ""))
		var terms: Array = category.get("terms", [])
		for term_variant in terms:
			if total >= MAX_MODERATION_TERMS:
				truncated = true
				push_warning(
					"LocalModerationAdapter: term cap %d reached at category '%s'; remaining terms skipped" %
					[MAX_MODERATION_TERMS, cat_name]
				)
				break
			var term_str := str(term_variant).strip_edges().to_lower()
			if term_str.is_empty():
				continue
			if not _term_lookup.has(term_str):
				_term_lookup[term_str] = {
					"category": cat_name,
					"severity": severity,
					"safe_alt": safe_alt,
				}
				total += 1

	if truncated:
		push_warning(
			"LocalModerationAdapter: term dict capped at %d (was over limit). " +
			"Add terms to a higher-priority category or raise MAX_MODERATION_TERMS." %
			MAX_MODERATION_TERMS
		)

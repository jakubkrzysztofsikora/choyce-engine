## Local rules-based moderation adapter for ModerationPort.
## Enforces text and image safety checks using Polish-first word lists
## with age-band differentiated severity. Defaults to BLOCK for unknown
## failures (fail-closed).
##
## Hardened with homoglyph defense: Cyrillic lookalikes and fullwidth
## characters are mapped to ASCII before matching. Polish diacritics
## are stripped so both composed and decomposed forms match the
## ASCII-based word lists.
##
## Phase 8b perf improvements:
## - _normalize_text and _tokenize fused into a single O(N) pass via
##   _normalize_and_tokenize; check_text calls the fused function.
## - Age-band extra_sets pre-built at setup() in _build_age_extra_sets()
##   instead of reconstructed per check_text call.
## - _build_term_lookup stores normalized form (critical fix) and routes
##   multi-word terms to _phrase_lookup.
## - unicode_at(i) used directly on the string instead of allocating a
##   1-char substring and calling .unicode_at(0) on it.
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

## Flat {normalized_single_token → {category, severity, safe_alt}} dict built at setup().
## Enables O(1) per-word lookup instead of nested category×term scan.
## Terms stored in NORMALIZED form so lookup matches _normalize_and_tokenize output.
var _term_lookup: Dictionary = {}

## Flat {normalized_phrase → {category, severity, safe_alt}} dict for multi-word terms.
## Matched by substring against the full normalized text (not the token array).
var _phrase_lookup: Dictionary = {}

## Pre-built per-age-band extra_set: {age_key → {normalized_term → true}}.
## Built once at setup(); avoids rebuilding the set on every check_text call.
var _age_extra_sets: Dictionary = {}

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
	_build_age_extra_sets()
	return self


func check_text(text: String, age_band: AgeBand) -> ModerationResult:
	if text.strip_edges().is_empty():
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")

	# Single fused pass: normalize + tokenize. Returns [normalized_string, token_array].
	var pair := _normalize_and_tokenize(text.strip_edges())
	var normalized_text: String = pair[0]
	var words: Array = pair[1]

	# Check age-band specific additional blocks via pre-built extra_set.
	var age_key := _age_band_key(age_band)
	if _age_extra_sets.has(age_key):
		var extra_set: Dictionary = _age_extra_sets[age_key]
		var override: Dictionary = _age_overrides.get(age_key, {})
		for word in words:
			var word_str := str(word)
			if extra_set.has(word_str):
				var alt: String = str(override.get("default_alternative", ""))
				return _blocked_result("age_restricted", alt, word_str)

	# O(N words) single-token lookup via flat _term_lookup dict.
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

	# Phrase (multi-word) substring pass on the full normalized text.
	for phrase in _phrase_lookup.keys():
		var phrase_str := str(phrase)
		if normalized_text.contains(phrase_str):
			var entry: Dictionary = _phrase_lookup[phrase_str]
			var severity: String = str(entry.get("severity", "block"))
			var cat_name: String = str(entry.get("category", ""))
			var safe_alt: String = str(entry.get("safe_alt", ""))
			if severity == "warn_child" and age_band != null and not age_band.is_child():
				var warn_result := ModerationResult.new(ModerationResult.Verdict.WARN, phrase_str)
				warn_result.category = cat_name
				warn_result.confidence = 0.8
				warn_result.safe_alternative = safe_alt
				return warn_result
			return _blocked_result(cat_name, safe_alt, phrase_str)

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


## Normalizes text: homoglyph → diacritic strip → leet digit map.
## Uses PackedStringArray to avoid repeated string concatenation.
## Note: unicode_at(i) read on lowered string avoids 1-char substring allocation
## where only the code point is needed; dictionary key lookups still need ch.
func _normalize_text(text: String) -> String:
	var lowered := text.to_lower()
	var len := lowered.length()
	var chars := PackedStringArray()
	chars.resize(len)
	for i in range(len):
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


## Fused normalize + tokenize: single O(N) pass over input.
## Returns [normalized_full_string, token_array].
## Avoids the double O(N) scan of calling _normalize_text then _tokenize separately.
## Uses normalized.unicode_at(i) directly in the tokenize step to skip the
## 1-char substring allocation that ch.unicode_at(0) would require.
func _normalize_and_tokenize(text: String) -> Array:
	var lowered := text.to_lower()
	var len := lowered.length()
	var norm_chars := PackedStringArray()
	norm_chars.resize(len)

	# Normalize pass: homoglyph → diacritic → leet.
	for i in range(len):
		var ch := lowered[i]
		if HOMOGLYPH_MAP.has(ch):
			norm_chars[i] = HOMOGLYPH_MAP[ch]
		elif POLISH_DIACRITIC_MAP.has(ch):
			norm_chars[i] = POLISH_DIACRITIC_MAP[ch]
		elif DIGIT_MAP.has(ch):
			norm_chars[i] = DIGIT_MAP[ch]
		else:
			norm_chars[i] = ch

	var normalized := "".join(norm_chars)

	# Tokenize pass: replace non-(a-z/space) chars with spaces.
	# unicode_at(i) on the already-built string avoids creating 1-char substrings.
	var tok_chars := PackedStringArray()
	tok_chars.resize(len)
	for i in range(len):
		var code := normalized.unicode_at(i)
		# a-z: 97-122, space: 32
		if (code >= 97 and code <= 122) or code == 32:
			tok_chars[i] = normalized[i]
		else:
			tok_chars[i] = " "

	var joined := "".join(tok_chars)
	var parts := joined.split(" ", false)
	var tokens: Array = []
	for part in parts:
		if not part.is_empty():
			tokens.append(part)

	return [normalized, tokens]


## Legacy tokenize: delegates to fused function. Kept for external callers.
func _tokenize(text: String) -> Array:
	var pair := _normalize_and_tokenize(text)
	return pair[1]


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
		# All 5 original multi-word photoreal terms restored.
		# Single-token terms → _term_lookup (O(1) word match).
		# Multi-word terms (whitespace in normalized form) → _phrase_lookup (substring).
		"photoreal_human": {
			"terms": [
				"photoreal",
				"fotorealistyczny",
				"selfie",
				"realistic human",
				"human portrait",
				"realistyczny czlowiek",
				"portret czlowieka",
				"photo-real",
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


## Builds the flat term lookup dicts after loading all categories.
## Single-token terms → _term_lookup (O(1) word match).
## Multi-word (whitespace after normalization) terms → _phrase_lookup (substring match).
## Both store NORMALIZED form so they match _normalize_and_tokenize output.
## Enforces MAX_MODERATION_TERMS cap by dropping lowest-priority categories first.
func _build_term_lookup() -> void:
	_term_lookup = {}
	_phrase_lookup = {}

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
			# Store NORMALIZED form so lookup matches _normalize_and_tokenize output.
			var term_str := _normalize_text(str(term_variant).strip_edges())
			if term_str.is_empty():
				continue
			var entry := {
				"category": cat_name,
				"severity": severity,
				"safe_alt": safe_alt,
			}
			if " " in term_str:
				# Multi-word → phrase lookup (substring match against full normalized text).
				if not _phrase_lookup.has(term_str):
					_phrase_lookup[term_str] = entry
					total += 1
			else:
				# Single token → word lookup (O(1) dict hit).
				if not _term_lookup.has(term_str):
					_term_lookup[term_str] = entry
					total += 1

	if truncated:
		push_warning(
			("LocalModerationAdapter: term dict capped at %d (was over limit). "
			+ "Add terms to a higher-priority category or raise MAX_MODERATION_TERMS.")
			% MAX_MODERATION_TERMS
		)


## Pre-builds per-age-band extra_set dicts once at setup() so check_text
## does not reconstruct them on every call. Terms stored in normalized form
## to match _normalize_and_tokenize token output.
func _build_age_extra_sets() -> void:
	_age_extra_sets = {}
	for age_key in _age_overrides.keys():
		var override: Dictionary = _age_overrides[age_key]
		var extra_blocked: Array = override.get("additional_blocked", [])
		var extra_set: Dictionary = {}
		for bt in extra_blocked:
			var norm := _normalize_text(str(bt).strip_edges())
			if not norm.is_empty():
				extra_set[norm] = true
		_age_extra_sets[str(age_key)] = extra_set

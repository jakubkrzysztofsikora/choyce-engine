## Polish-first localization policy adapter for LocalizationPolicyPort.
## Loads optional translation/glossary files and enforces safe terminology.
class_name PolishLocalizationPolicy
extends LocalizationPolicyPort

var _locale: String = "pl-PL"
var _translations: Dictionary = {}
var _unsafe_terms: Dictionary = {}
var _preferred_terms: Dictionary = {}
var _preferred_terms_parent: Dictionary = {}
var _translations_file: String = "res://data/localization/ui_pl.json"
var _kid_glossary_file: String = "res://data/localization/glossary_kid_pl.json"
var _parent_glossary_file: String = "res://data/localization/glossary_parent_pl.json"


func _init(
	locale: String = "pl-PL",
	translations_file: String = "res://data/localization/ui_pl.json",
	kid_glossary_file: String = "res://data/localization/glossary_kid_pl.json",
	parent_glossary_file: String = "res://data/localization/glossary_parent_pl.json"
) -> void:
	setup(locale, translations_file, kid_glossary_file, parent_glossary_file)


func setup(
	locale: String = "pl-PL",
	translations_file: String = "res://data/localization/ui_pl.json",
	kid_glossary_file: String = "res://data/localization/glossary_kid_pl.json",
	parent_glossary_file: String = "res://data/localization/glossary_parent_pl.json"
) -> PolishLocalizationPolicy:
	_locale = locale.strip_edges()
	if _locale.is_empty():
		_locale = "pl-PL"

	_translations_file = translations_file.strip_edges()
	_kid_glossary_file = kid_glossary_file.strip_edges()
	_parent_glossary_file = parent_glossary_file.strip_edges()

	_load_defaults()
	_load_translations_file()
	_load_glossary_file(_kid_glossary_file, true)
	_load_glossary_file(_parent_glossary_file, false)
	return self


func get_locale() -> String:
	return _locale


func translate(key: String) -> String:
	var clean_key := key.strip_edges()
	if clean_key.is_empty():
		return ""

	if _translations.has(clean_key):
		return str(_translations[clean_key])
	return clean_key


func is_term_safe(term: String) -> bool:
	var normalized := term.strip_edges().to_lower()
	if normalized.is_empty():
		return false

	if _unsafe_terms.has(normalized):
		return false

	for blocked in _unsafe_terms.keys():
		if normalized.contains(str(blocked)):
			return false

	return true


func get_preferred_term(term_key: String) -> String:
	var clean_key := term_key.strip_edges()
	if clean_key.is_empty():
		return ""
	if _preferred_terms.has(clean_key):
		return str(_preferred_terms[clean_key])
	return clean_key


func get_parent_term(term_key: String) -> String:
	var clean_key := term_key.strip_edges()
	if clean_key.is_empty():
		return ""
	if _preferred_terms_parent.has(clean_key):
		return str(_preferred_terms_parent[clean_key])
	if _preferred_terms.has(clean_key):
		return str(_preferred_terms[clean_key])
	return clean_key


func _load_defaults() -> void:
	_translations = {
		"ui.home.create": "Tworz",
		"ui.home.play": "Graj",
		"ui.home.library": "Biblioteka rodzinna",
		"ui.home.parent_zone": "Strefa rodzica",
		"ui.common.undo": "Cofnij",
		"ui.common.safe_restore": "Przywroc bezpieczny zapis",
	}

	_unsafe_terms = {}
	for term in [
		"narkotyk",
		"narkotyki",
		"hazard",
		"bron",
		"zabij",
		"przemoc",
		"alkohol",
	]:
		_unsafe_terms[term] = true

	_preferred_terms = {
		"quest": "misja",
		"hint": "wskazowka",
		"build": "buduj",
		"playtest": "test zabawy",
	}

	_preferred_terms_parent = {
		"quest": "zadanie",
		"hint": "wskazowka",
		"build": "tworzenie",
		"playtest": "sesja testowa",
		"moderation": "moderacja",
		"policy": "polityka",
		"publish": "publikacja",
	}


func _load_translations_file() -> void:
	var parsed = _read_json(_translations_file)
	if not (parsed is Dictionary):
		return

	var source: Dictionary = parsed
	if source.has("translations") and source["translations"] is Dictionary:
		source = source["translations"]

	for key in source.keys():
		_translations[str(key)] = str(source[key])


func _load_glossary_file(path: String, include_unsafe_terms: bool) -> void:
	var parsed = _read_json(path)
	if not (parsed is Dictionary):
		return

	var glossary: Dictionary = parsed

	if include_unsafe_terms:
		var unsafe_terms_variant = glossary.get("unsafe_terms", [])
		if unsafe_terms_variant is Array:
			for term in unsafe_terms_variant:
				var normalized := str(term).strip_edges().to_lower()
				if not normalized.is_empty():
					_unsafe_terms[normalized] = true

	var preferred_terms_variant = glossary.get("preferred_terms", {})
	if preferred_terms_variant is Dictionary:
		for key in preferred_terms_variant.keys():
			if include_unsafe_terms:
				_preferred_terms[str(key)] = str(preferred_terms_variant[key])
			else:
				_preferred_terms_parent[str(key)] = str(preferred_terms_variant[key])


func _read_json(path: String) -> Variant:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())

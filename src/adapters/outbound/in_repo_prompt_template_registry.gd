## Repository-backed prompt template registry.
## Loads versioned templates and regression fixtures from in-repo JSON files.
class_name InRepoPromptTemplateRegistry
extends "res://src/ports/outbound/prompt_template_registry_port.gd"

const DEFAULT_TEMPLATES_PATH := "res://data/ai/prompt_templates.json"
const DEFAULT_FIXTURES_PATH := "res://data/ai/prompt_regression_fixtures.json"

var _templates_path: String = DEFAULT_TEMPLATES_PATH
var _fixtures_path: String = DEFAULT_FIXTURES_PATH
var _default_locale: String = "pl-PL"
var _templates: Array[Dictionary] = []
var _fixtures: Array[Dictionary] = []


func _init(
	templates_path: String = DEFAULT_TEMPLATES_PATH,
	fixtures_path: String = DEFAULT_FIXTURES_PATH
) -> void:
	setup(templates_path, fixtures_path)


func setup(
	templates_path: String = DEFAULT_TEMPLATES_PATH,
	fixtures_path: String = DEFAULT_FIXTURES_PATH
) -> InRepoPromptTemplateRegistry:
	_templates_path = templates_path.strip_edges()
	if _templates_path.is_empty():
		_templates_path = DEFAULT_TEMPLATES_PATH

	_fixtures_path = fixtures_path.strip_edges()
	if _fixtures_path.is_empty():
		_fixtures_path = DEFAULT_FIXTURES_PATH

	_templates.clear()
	_fixtures.clear()
	_default_locale = "pl-PL"
	_load_templates_file()
	_load_fixtures_file()
	return self


func resolve_template(
	use_case: String,
	locale: String,
	role: String,
	age_band: String,
	version: String = "latest"
) -> Dictionary:
	var clean_use_case := use_case.strip_edges().to_lower()
	var clean_role := _normalize_role(role)
	var clean_age_band := _normalize_age_band(age_band)
	var requested_locale := _enforce_locale_policy(locale, clean_role, clean_age_band)

	if clean_use_case.is_empty():
		return _fallback_template("", requested_locale, clean_role, clean_age_band)

	var candidates: Array[Dictionary] = []
	for entry in _templates:
		if str(entry.get("use_case", "")).strip_edges().to_lower() == clean_use_case:
			candidates.append(entry)

	if candidates.is_empty():
		return _fallback_template(clean_use_case, requested_locale, clean_role, clean_age_band)

	var requested_version := version.strip_edges().to_lower()
	if requested_version != "" and requested_version != "latest":
		var exact_version: Array[Dictionary] = []
		for candidate in candidates:
			if str(candidate.get("version", "")).strip_edges().to_lower() == requested_version:
				exact_version.append(candidate)
		if not exact_version.is_empty():
			candidates = exact_version

	var best: Dictionary = {}
	var best_score := -1
	var best_version := -1
	for candidate in candidates:
		var score := _score_template(candidate, requested_locale, clean_role, clean_age_band)
		var version_score := _version_weight(str(candidate.get("version", "")))
		if score > best_score:
			best_score = score
			best_version = version_score
			best = candidate
		elif score == best_score and (requested_version == "" or requested_version == "latest"):
			if version_score > best_version:
				best_version = version_score
				best = candidate

	if best.is_empty():
		return _fallback_template(clean_use_case, requested_locale, clean_role, clean_age_band)

	var resolved_locale := _normalize_locale(str(best.get("locale", requested_locale)))
	return {
		"template_id": _template_id(best),
		"use_case": clean_use_case,
		"version": str(best.get("version", "")),
		"locale": resolved_locale,
		"role": str(best.get("role", "any")).strip_edges().to_lower(),
		"age_band": str(best.get("age_band", "ANY")).strip_edges().to_upper(),
		"system_prompt": str(best.get("system_prompt", "")).strip_edges(),
		"user_prefix": str(best.get("user_prefix", "")).strip_edges(),
	}


func list_versions(use_case: String) -> Array[String]:
	var clean_use_case := use_case.strip_edges().to_lower()
	var seen: Dictionary = {}
	for entry in _templates:
		if clean_use_case.is_empty() or str(entry.get("use_case", "")).strip_edges().to_lower() == clean_use_case:
			var version := str(entry.get("version", "")).strip_edges()
			if not version.is_empty():
				seen[version] = true

	var versions: Array[String] = []
	for key in seen.keys():
		versions.append(str(key))
	versions.sort_custom(func(a: String, b: String) -> bool:
		return _compare_versions(a, b) > 0
	)
	return versions


func get_regression_fixtures(use_case: String = "") -> Array[Dictionary]:
	var clean_use_case := use_case.strip_edges().to_lower()
	if clean_use_case.is_empty():
		return _fixtures.duplicate(true)

	var result: Array[Dictionary] = []
	for fixture in _fixtures:
		if str(fixture.get("use_case", "")).strip_edges().to_lower() == clean_use_case:
			result.append(fixture.duplicate(true))
	return result


func _load_templates_file() -> void:
	var parsed: Variant = _read_json(_templates_path)
	if not (parsed is Dictionary):
		return

	var root := parsed as Dictionary
	var candidate_locale := str(root.get("default_locale", "pl-PL")).strip_edges()
	_default_locale = _normalize_locale(candidate_locale)

	var template_entries: Variant = root.get("templates", [])
	if not (template_entries is Array):
		return

	for item in template_entries:
		if not (item is Dictionary):
			continue
		var entry: Dictionary = (item as Dictionary).duplicate(true)
		if str(entry.get("use_case", "")).strip_edges().is_empty():
			continue
		if str(entry.get("version", "")).strip_edges().is_empty():
			continue
		entry["locale"] = _normalize_locale(str(entry.get("locale", _default_locale)))
		entry["role"] = _normalize_role(str(entry.get("role", "any")))
		entry["age_band"] = _normalize_age_band(str(entry.get("age_band", "ANY")))
		_templates.append(entry)


func _load_fixtures_file() -> void:
	var parsed: Variant = _read_json(_fixtures_path)
	if not (parsed is Dictionary):
		return

	var root := parsed as Dictionary
	var fixture_entries: Variant = root.get("fixtures", [])
	if not (fixture_entries is Array):
		return

	for item in fixture_entries:
		if item is Dictionary:
			_fixtures.append((item as Dictionary).duplicate(true))


func _score_template(entry: Dictionary, locale: String, role: String, age_band: String) -> int:
	var score := 0
	var template_locale := _normalize_locale(str(entry.get("locale", _default_locale)))
	if template_locale == locale:
		score += 100
	elif template_locale.get_slice("-", 0) == locale.get_slice("-", 0):
		score += 85
	elif template_locale == _default_locale:
		score += 70

	var template_role := _normalize_role(str(entry.get("role", "any")))
	if template_role == role:
		score += 30
	elif template_role == "any":
		score += 10

	var template_age := _normalize_age_band(str(entry.get("age_band", "ANY")))
	if template_age == age_band:
		score += 20
	elif template_age == "ANY":
		score += 8

	return score


func _template_id(entry: Dictionary) -> String:
	var explicit_id := str(entry.get("template_id", "")).strip_edges()
	if not explicit_id.is_empty():
		return explicit_id
	return "%s:%s:%s:%s:%s" % [
		str(entry.get("use_case", "")).strip_edges().to_lower(),
		str(entry.get("version", "")).strip_edges(),
		_normalize_locale(str(entry.get("locale", _default_locale))),
		_normalize_role(str(entry.get("role", "any"))),
		_normalize_age_band(str(entry.get("age_band", "ANY"))),
	]


func _version_weight(version: String) -> int:
	var tuple := _version_tuple(version)
	return int(tuple[0]) * 10000 + int(tuple[1]) * 100 + int(tuple[2])


func _compare_versions(left: String, right: String) -> int:
	var a := _version_tuple(left)
	var b := _version_tuple(right)
	for idx in range(3):
		if int(a[idx]) > int(b[idx]):
			return 1
		if int(a[idx]) < int(b[idx]):
			return -1
	return 0


func _version_tuple(version: String) -> Array[int]:
	var clean := version.strip_edges().replace("v", "")
	var parts := clean.split(".")
	var values: Array[int] = [0, 0, 0]
	for idx in range(mini(parts.size(), 3)):
		values[idx] = int(parts[idx])
	return values


func _normalize_locale(locale: String) -> String:
	var clean := locale.strip_edges()
	if clean.is_empty():
		return _default_locale
	if clean.contains("_"):
		clean = clean.replace("_", "-")
	if clean.begins_with("pl"):
		return "pl-PL"
	if clean.length() == 2:
		return "%s-%s" % [clean.to_lower(), clean.to_upper()]
	return clean


func _normalize_role(role: String) -> String:
	var clean := role.strip_edges().to_lower()
	match clean:
		"kid", "child":
			return "kid"
		"parent", "adult":
			return "parent"
		"any", "*", "":
			return "any"
		_:
			return clean


func _normalize_age_band(age_band: String) -> String:
	var clean := age_band.strip_edges().to_upper()
	if clean.is_empty() or clean == "*":
		return "ANY"
	return clean


func _enforce_locale_policy(locale: String, role: String, age_band: String) -> String:
	var normalized := _normalize_locale(locale)
	if role == "kid" or age_band == "CHILD_6_8" or age_band == "CHILD_9_12":
		if not normalized.begins_with("pl"):
			return "pl-PL"
	return normalized


func _fallback_template(use_case: String, locale: String, role: String, age_band: String) -> Dictionary:
	return {
		"template_id": "fallback:%s" % use_case,
		"use_case": use_case,
		"version": "0.0.0",
		"locale": _enforce_locale_policy(locale, role, age_band),
		"role": role,
		"age_band": age_band,
		"system_prompt": "",
		"user_prefix": "",
	}


func _read_json(path: String) -> Variant:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())

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
		"ui.common.safe_restore": "Przywróć bezpieczny zapis",
		# Phase 4a-4: onboarding_overlay keys (kid register: ≤6 words, 2nd person)
		"onboarding.celebrate": "Świetna robota!",
		"onboarding.skip": "Pomiń",
		"onboarding.tts_prompt": "Możesz pominąć. Naciśnij ucho.",
		# Phase 4a-5: captions_overlay keys (no hardcoded Polish in captions at runtime;
		# keys reserved for future caption-label UI if added)
		"captions.position.bottom": "Napisy: na dole",
		"captions.position.top": "Napisy: na górze",
		"captions.font_size.label": "Powiększ tekst",
		"captions.high_contrast.label": "Mocne kolory",
		"captions.tts_narration.label": "Czytaj napisy głosem",
		# Phase 2: COPPA parent data-lifecycle tab keys (parent-only UI)
		"parent.coppa.tab": "Dane mojego dziecka",
		"parent.coppa.export": "Eksportuj dane",
		"parent.coppa.delete": "Usuń dane",
		"parent.coppa.delete_confirm.title": "Usunąć dane?",
		"parent.coppa.delete_confirm.body": "To zniknie i nie wróci.",
		"parent.coppa.export_ok": "Zapisałem dane.",
		"parent.coppa.delete_ok": "Usunąłem dane.",
		# FR-022: voice moderation feedback keys (kid-register: ≤6 words, clear feedback)
		"voice.blocked_try_again": "Spróbuj inaczej.",
		"voice.no_speech": "Nie usłyszałem cię. Spróbuj jeszcze raz.",
		# Phase 4a-1: create_shell strings (kid register: ≤6 words, 2nd-person imperative)
		"create.steps.intro": "Stwórz: 1) Umieść 2) Pomaluj 3) Zagraj.",
		"create.status.title": "Status tworzenia",
		"create.node_list.title": "Obiekty w świecie",
		"create.hint.choose_tool": "Wybierz narzędzie. Zacznij od Umieść.",
		"create.tool_selected": "Wybrałeś: %s.",
		"create.error.port_not_ready": "Tryb tworzenia niegotowy. Uruchom ponownie.",
		"create.error.no_world": "Brak aktywnego świata. Kliknij Umieść.",
		"create.error.no_selection": "Wybierz obiekt lub dodaj przez Umieść.",
		"create.object.default_name": "Nowy obiekt",
		"create.error.edit_failed": "Zmiana niezapisana. Wybierz inny obiekt.",
		"create.error.no_config": "Brak konfiguracji. Tryb tworzenia nieaktywny.",
		"create.error.world_create_failed": "Nie udało się utworzyć świata.",
		"create.error.world_invalid": "Świat ma niepoprawny format.",
		"create.world_ready": "Świat gotowy. Dodaj obiekt przez Umieść.",
		"create.error.playtest_unavailable": "Playtest chwilowo niedostępny.",
		"create.error.playtest_no_world": "Najpierw utwórz świat.",
		"create.guest_name": "Gość",
		"create.playtest.running": "Test uruchomiony: %s",
		"create.playtest.mode_coop": "kooperacja",
		"create.playtest.mode_solo": "solo",
		"create.playtest.started": "Playtest uruchomiony. Przejdź do Graj.",
		"create.error.playtest_failed": "Playtest nieudany. Dodaj obiekt.",
		"create.world_summary.empty": "Świat: brak | Obiekty: 0",
		"create.selection.none": "Zaznaczenie: brak",
		"create.node_list.empty": "Brak obiektów. Kliknij Umieść.",
		"create.world_summary.full": "Świat: %s | Obiekty: %d",
		"create.selection.active": "Zaznaczenie: %s",
		"create.object.fallback_name": "Obiekt",
		"create.object_selected": "Wybrano obiekt: %s.",
		"create.tool.place": "Umieść",
		"create.tool.paint": "Pomaluj",
		"create.tool.move": "Przesuń",
		"create.tool.duplicate": "Duplikuj",
		"create.tool.unknown": "Narzędzie",
		"create.success.add": "Dodano obiekt: %s.",
		"create.success.paint": "Pomalowano obiekt: %s.",
		"create.success.move": "Przesunięto obiekt: %s.",
		"create.success.duplicate": "Utworzono kopię obiektu.",
		"create.success.generic": "Zmiana zapisana.",
		"create.template_selected": "Wybrano szablon: %s",
		"create.onboarding.welcome": "Witaj! Zaczynamy budowanie.",
		"create.onboarding.place_first": "Kliknij tu, aby ustawić obiekt.",
		"create.onboarding.paint_first": "Teraz pomaluj swój obiekt.",
		"create.onboarding.play": "Naciśnij Graj, aby przetestować.",
		"create.onboarding.continue": "Kontynuuj...",
		"create.ai.applied": "Zmiana AI zatwierdzona i zastosowana.",
		# Phase 9: tool-buttons disabled tooltip when port unavailable
		"create.tools.unavailable": "Narzędzia niedostępne. Spróbuj ponownie.",
		# ui.create.* keys used by create_shell _t() fallback and PolishLocalizationPolicy
		"ui.create.title": "Tryb tworzenia",
		"ui.create.info": "Wybierz szablon, zbuduj świat i uruchom test.",
		"ui.create.go_play": "Przejdź do gry",
		"ui.create.go_library": "Przejdź do biblioteki",
		"ui.tool.place": "Umieść",
		"ui.tool.paint": "Pomaluj",
		"ui.tool.move": "Przesuń",
		"ui.tool.duplicate": "Duplikuj",
		"ui.tooltip.place": "Umieść obiekt na planszy.",
		"ui.tooltip.paint": "Nadaj obiektowi kolor.",
		"ui.tooltip.move": "Przesuń zaznaczony obiekt.",
		"ui.tooltip.duplicate": "Utwórz kopię zaznaczonego obiektu.",
		# FR-025 / Phase 9: library RBAC + ports_ready feedback keys
		# library.* — kid-facing (kid register: ≤6 words, clear, no jargon)
		# ui.library.* — parent-facing action confirmations (adult-formal register)
		"library.access_denied": "Tylko rodzic.",
		"library.approve.toast_ok": "Zatwierdzone.",
		"library.reject.toast_ok": "Odrzucone.",
		"library.unpublish.toast_ok": "Cofnięte.",
		"library.error.port_unavailable": "Coś nie działa. Spróbuj później.",
		"library.error.ports_not_ready": "Chwilę...",
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

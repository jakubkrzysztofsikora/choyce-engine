## Wave C: Tests for kid-register Polish fixes in PolishLocalizationPolicy.
## MUST criteria:
##   M1 - create.error.no_config value drops "konfiguracja", uses clear phrasing
##   M2 - create.tools.unavailable value uses playful "śpią" phrasing
##   M3 - library.error.port_unavailable value uses "za chwilę" not "później"
##   M4 - create.error.port_not_ready value uses "śpi" kid-friendly phrasing
##   M5 - ui.create.info value uses 3-short-imperative form (≤6 words total)
extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var policy := PolishLocalizationPolicy.new()

	# M1 - create.error.no_config must NOT contain "konfiguracji" and must be clear
	var v1 := policy.translate("create.error.no_config")
	if "konfiguracji" in v1 or "konfiguracja" in v1:
		failures.append("FAIL M1: create.error.no_config still contains 'konfiguracja': '%s'" % v1)
	if v1 == "create.error.no_config":
		failures.append("FAIL M1: create.error.no_config key not found in policy")
	if not failures.is_empty() and failures[-1].begins_with("FAIL M1"):
		pass
	elif not ("Spróbuj" in v1 or "spróbuj" in v1):
		failures.append("FAIL M1: create.error.no_config missing 'Spróbuj' encouragement: '%s'" % v1)

	# M2 - create.tools.unavailable must contain "śpią" (playful, not "niedostępne")
	var v2 := policy.translate("create.tools.unavailable")
	if "niedostępne" in v2:
		failures.append("FAIL M2: create.tools.unavailable still contains 'niedostępne': '%s'" % v2)
	if "śpią" not in v2:
		failures.append("FAIL M2: create.tools.unavailable missing 'śpią': '%s'" % v2)

	# M3 - library.error.port_unavailable must use "za chwilę" not "później"
	var v3 := policy.translate("library.error.port_unavailable")
	if "później" in v3:
		failures.append("FAIL M3: library.error.port_unavailable still contains 'później': '%s'" % v3)
	if "chwilę" not in v3:
		failures.append("FAIL M3: library.error.port_unavailable missing 'chwilę': '%s'" % v3)

	# M4 - create.error.port_not_ready must contain "śpi" and not "Uruchom ponownie"
	var v4 := policy.translate("create.error.port_not_ready")
	if "Uruchom ponownie" in v4:
		failures.append("FAIL M4: create.error.port_not_ready still contains 'Uruchom ponownie': '%s'" % v4)
	if "śpi" not in v4:
		failures.append("FAIL M4: create.error.port_not_ready missing 'śpi': '%s'" % v4)

	# M5 - ui.create.info must be the short 3-imperative form (not the long sentence)
	var v5 := policy.translate("ui.create.info")
	if "zbuduj świat i uruchom test" in v5:
		failures.append("FAIL M5: ui.create.info still contains old long sentence: '%s'" % v5)
	# Short form: "Wybierz szablon. Buduj. Graj." — check word count ≤6
	var word_count := v5.split(" ").size()
	if word_count > 6:
		failures.append("FAIL M5: ui.create.info exceeds 6 words (%d): '%s'" % [word_count, v5])

	if failures.is_empty():
		print("WAVE_C_L10N_KID_REGISTER_TEST: PASS")
		quit(0)
	else:
		for msg in failures:
			print("WAVE_C_L10N_KID_REGISTER_TEST: %s" % msg)
		quit(1)

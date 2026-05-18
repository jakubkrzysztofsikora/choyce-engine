## Regression tests for LocalModerationAdapter critical safety fixes.
##
## Covers:
##   MUST-1  Term-lookup normalization: diacritic term stored normalized, matched via stripped input.
##   MUST-2  Age-override extra_set normalization: diacritic term in additional_blocked matched via stripped input.
##   MUST-3  Multi-word phrase matching: 5 original photoreal phrases blocked as substrings.
##   MUST-4  Single-token photoreal terms still blocked (regression guard).
##   MUST-5  Default age-override words still blocked for 6yo.
extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var checks := 0

	var age_child := AgeBand.new(AgeBand.Band.CHILD_6_8)

	# ── MUST-1: term-lookup stores normalized form (diacritic → ASCII) ─────────
	# "zabić" in category terms must match check_text("zabic ...") because both
	# are stored/queried in normalized form after the fix.
	var adapter_diacritic := LocalModerationAdapter.new()
	adapter_diacritic._categories = {
		"violence": {
			"terms": ["zabić"],   # composed Polish form — stored with diacritic
			"safe_alternative": "safe",
			"severity": "block",
		}
	}
	adapter_diacritic._age_overrides = {}
	adapter_diacritic._image_rules = {}
	adapter_diacritic._build_term_lookup()

	checks += 1
	var res_diacritic := adapter_diacritic.check_text("zabic komus", age_child)
	if not res_diacritic.is_blocked():
		failures.append(
			"MUST-1: term stored as 'zabić' must block check_text('zabic komus') after normalization"
		)

	checks += 1
	var res_diacritic_direct := adapter_diacritic.check_text("zabić komus", age_child)
	if not res_diacritic_direct.is_blocked():
		failures.append(
			"MUST-1b: term 'zabić' must also block the diacritic form 'zabić komus'"
		)

	# ── MUST-2: age-override extra_set uses normalized form ────────────────────
	# Rules contain "zabić" as additional_blocked for CHILD_6_8.
	# check_text("zabic") for a 6yo must return BLOCK.
	var adapter_age := LocalModerationAdapter.new()
	adapter_age._categories = {}
	adapter_age._age_overrides = {
		"CHILD_6_8": {
			"additional_blocked": ["zabić"],   # diacritic form in rules
			"default_alternative": "Spokojniej!",
		}
	}
	adapter_age._image_rules = {}
	adapter_age._build_term_lookup()

	checks += 1
	var res_age_norm := adapter_age.check_text("zabic cos", age_child)
	if not res_age_norm.is_blocked():
		failures.append(
			"MUST-2: age-override extra_set with 'zabić' must block 'zabic cos' for 6yo"
		)

	checks += 1
	var res_age_diacritic := adapter_age.check_text("zabić cos", age_child)
	if not res_age_diacritic.is_blocked():
		failures.append(
			"MUST-2b: age-override 'zabić' must also block diacritic form 'zabić cos'"
		)

	# ── MUST-3: multi-word phrase matching (photoreal coverage restore) ─────────
	var adapter_phrases := LocalModerationAdapter.new().setup("")

	checks += 1
	var res_realistic_human := adapter_phrases.check_text("draw a realistic human for me", age_child)
	if not res_realistic_human.is_blocked():
		failures.append(
			"MUST-3a: 'draw a realistic human for me' must be blocked (phrase: realistic human)"
		)

	checks += 1
	var res_portret := adapter_phrases.check_text("portret czlowieka w grze", age_child)
	if not res_portret.is_blocked():
		failures.append(
			"MUST-3b: 'portret czlowieka w grze' must be blocked (phrase: portret czlowieka)"
		)

	checks += 1
	var res_portret_diacritic := adapter_phrases.check_text("portret człowieka", age_child)
	if not res_portret_diacritic.is_blocked():
		failures.append(
			"MUST-3c: 'portret człowieka' (with diacritics) must be blocked"
		)

	checks += 1
	var res_human_portrait := adapter_phrases.check_text("generate a human portrait", age_child)
	if not res_human_portrait.is_blocked():
		failures.append(
			"MUST-3d: 'generate a human portrait' must be blocked (phrase: human portrait)"
		)

	checks += 1
	var res_realistyczny := adapter_phrases.check_text("realistyczny czlowiek w tle", age_child)
	if not res_realistyczny.is_blocked():
		failures.append(
			"MUST-3e: 'realistyczny czlowiek w tle' must be blocked (phrase: realistyczny czlowiek)"
		)

	checks += 1
	var res_photo_real := adapter_phrases.check_text("styl photo-real prosze", age_child)
	if not res_photo_real.is_blocked():
		failures.append(
			"MUST-3f: 'styl photo-real prosze' must be blocked (phrase: photo-real)"
		)

	# ── MUST-4: single-token photoreal terms still blocked ──────────────────────
	for phrase in ["photoreal robot", "zrob selfie postaci", "fotorealistyczny las"]:
		checks += 1
		var r := adapter_phrases.check_text(phrase, age_child)
		if not r.is_blocked():
			failures.append("MUST-4: single-token '%s' must still be blocked" % phrase)

	# ── MUST-5: default age-override terms blocked for 6yo ──────────────────────
	for word in ["straszny", "potwor", "smierc"]:
		checks += 1
		var r := adapter_phrases.check_text(word, age_child)
		if not r.is_blocked():
			failures.append("MUST-5: age-restricted word '%s' must block for CHILD_6_8" % word)

	if failures.is_empty():
		print("[PASS] LocalModerationAdapterRegressions (%d checks)" % checks)
		quit(0)
		return

	print("[FAIL] LocalModerationAdapterRegressions")
	for item in failures:
		print("  - %s" % item)
	print("Checks: %d" % checks)
	quit(1)

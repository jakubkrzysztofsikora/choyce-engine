extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var checks := 0

	var registry_script_variant: Variant = load("res://src/adapters/outbound/in_repo_prompt_template_registry.gd")
	if not (registry_script_variant is Script):
		print("[FAIL] Failed to load prompt template registry script")
		quit(1)
		return
	var registry_script: Script = registry_script_variant
	var registry: Variant = registry_script.new().setup(
		"res://data/ai/prompt_templates.json",
		"res://data/ai/prompt_regression_fixtures.json"
	)

	var fixtures: Array = registry.call("get_regression_fixtures")
	if fixtures.is_empty():
		print("[FAIL] Prompt regression fixtures list is empty")
		quit(1)
		return

	for fixture_variant in fixtures:
		if not (fixture_variant is Dictionary):
			continue
		var fixture: Dictionary = fixture_variant
		var use_case := str(fixture.get("use_case", ""))
		var locale := str(fixture.get("locale", "pl-PL"))
		var role := str(fixture.get("role", "kid"))
		var age_band := str(fixture.get("age_band", "CHILD_6_8"))
		var version := str(fixture.get("template_version", "latest"))
		var fixture_id := str(fixture.get("fixture_id", "unknown"))

		var resolved_variant: Variant = registry.call(
			"resolve_template",
			use_case,
			locale,
			role,
			age_band,
			version
		)
		if not (resolved_variant is Dictionary):
			failures.append("%s: resolved template is not a dictionary" % fixture_id)
			continue
		var resolved: Dictionary = resolved_variant

		checks += 1
		var expected_markers_variant: Variant = fixture.get("expected_markers", [])
		if expected_markers_variant is Array:
			var prompt_blob := (
				str(resolved.get("system_prompt", "")) + " " + str(resolved.get("user_prefix", ""))
			).to_lower()
			for marker_variant in expected_markers_variant:
				var marker := str(marker_variant).to_lower()
				if marker.is_empty():
					continue
				checks += 1
				if not prompt_blob.contains(marker):
					failures.append("%s: expected marker '%s' missing" % [fixture_id, marker])

	# Policy guard sanity check: kid locale should remain Polish.
	var kid_guard: Dictionary = registry.call(
		"resolve_template",
		"ai_creation_help",
		"en-US",
		"kid",
		"CHILD_6_8"
	)
	checks += 1
	if str(kid_guard.get("locale", "")) != "pl-PL":
		failures.append("kid_locale_guard: expected pl-PL locale")

	if failures.is_empty():
		print("[PASS] PromptRegression (%d checks)" % checks)
		quit(0)
		return

	print("[FAIL] PromptRegression")
	for item in failures:
		print("  - %s" % item)
	print("Checks: %d" % checks)
	quit(1)

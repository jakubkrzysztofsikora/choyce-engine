extends SceneTree

func _init() -> void:
	var policy := PolishLocalizationPolicy.new()
	# We don't call setup() because we want to inject test data manually 
	# effectively testing the logic of get_parent_term isolated from file I/O.
	
	# Inject mock data directly into private dictionaries (using GDScript dynamic access to verify logic)
	policy._preferred_terms = {
		"term_kid_only": "dzieciak",
		"term_shared": "wspolny_dziecko"
	}
	
	policy._preferred_terms_parent = {
		"term_parent_only": "rodzic",
		"term_shared": "wspolny_rodzic"
	}

	var failures: Array[String] = []

	# Case 1: Parent-specific term
	var res1 := policy.get_parent_term("term_parent_only")
	if res1 != "rodzic":
		failures.append("FAIL: expected 'rodzic', got '%s'" % res1)

	# Case 2: Shared term (Parent override should win in get_parent_term)
	var res2 := policy.get_parent_term("term_shared")
	if res2 != "wspolny_rodzic":
		failures.append("FAIL: expected 'wspolny_rodzic' (override), got '%s'" % res2)

	# Case 3: Kid-only term (Fallback to kid glossary if not in parent)
	var res3 := policy.get_parent_term("term_kid_only")
	if res3 != "dzieciak":
		failures.append("FAIL: expected 'dzieciak' (fallback), got '%s'" % res3)

	# Case 4: Unknown term (Fallback to key)
	var res4 := policy.get_parent_term("term_unknown")
	if res4 != "term_unknown":
		failures.append("FAIL: expected 'term_unknown', got '%s'" % res4)

	if failures.is_empty():
		print("LOCALIZATION_POLICY_TEST: PASS")
		quit(0)
	else:
		for msg in failures:
			print("LOCALIZATION_POLICY_TEST: %s" % msg)
		quit(1)

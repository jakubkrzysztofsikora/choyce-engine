extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var checks := 0

	var moderation := LocalModerationAdapter.new().setup("")
	var age := AgeBand.new(AgeBand.Band.CHILD_6_8)

	# 1. Cyrillic lookalike "о" (U+043E) should map to Latin "o" and match "bron"
	checks += 1
	var cyrillic_bron := moderation.check_text("brоn", age)
	if not cyrillic_bron.is_blocked():
		failures.append("Cyrillic lookalike 'brоn' (with Cyrillic o) should match 'bron' and be blocked")

	# 2. Fullwidth lookalike should map to ASCII
	checks += 1
	var fullwidth := moderation.check_text("ｋarabin", age)
	if not fullwidth.is_blocked():
		failures.append("Fullwidth lookalike 'ｋarabin' should match 'karabin' and be blocked")

	# 3. Polish diacritic "ć" should normalize to "c" and match "zabic"
	checks += 1
	var polish_diacritic := moderation.check_text("zabić", age)
	if not polish_diacritic.is_blocked():
		failures.append("Polish diacritic 'zabić' should normalize to 'zabic' and be blocked")

	# 4. Mixed homoglyphs and punctuation
	checks += 1
	var mixed := moderation.check_text("Daj mi brоn!", age)
	if not mixed.is_blocked():
		failures.append("Mixed homoglyph 'brоn!' should be blocked")

	# 5. Benign text should pass
	checks += 1
	var benign := moderation.check_text("Zbuduj ladny domek", age)
	if benign.is_blocked():
		failures.append("Benign text 'Zbuduj ladny domek' should pass moderation")

	# 6. Digit stripping: "br0n" should still match "bron"
	checks += 1
	var digit_evasion := moderation.check_text("br0n", age)
	if not digit_evasion.is_blocked():
		failures.append("Digit-stripped 'br0n' should match 'bron' and be blocked")

	# 7. Uppercase Cyrillic should also be normalized (after to_lower)
	checks += 1
	var uppercase_cyrillic := moderation.check_text("BRОN", age)  # Cyrillic О
	if not uppercase_cyrillic.is_blocked():
		failures.append("Uppercase Cyrillic 'BRОN' should normalize to 'bron' and be blocked")

	if failures.is_empty():
		print("[PASS] HomoglyphModeration (%d checks)" % checks)
		quit(0)
		return

	print("[FAIL] HomoglyphModeration")
	for item in failures:
		print("  - %s" % item)
	print("Checks: %d" % checks)
	quit(1)

class_name LocalModerationAdapterContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()

	# Setup adapter with defaults only (no file loading in test)
	var adapter := LocalModerationAdapter.new().setup("")
	var child_6_8 := AgeBand.new(AgeBand.Band.CHILD_6_8)
	var child_9_12 := AgeBand.new(AgeBand.Band.CHILD_9_12)
	var teen := AgeBand.new(AgeBand.Band.TEEN)
	var parent := AgeBand.new(AgeBand.Band.PARENT)

	# Safe text should pass
	var safe_result := adapter.check_text("Zbuduj ladny domek", child_6_8)
	_assert_true(
		safe_result.verdict == ModerationResult.Verdict.PASS,
		"Safe Polish text should pass moderation"
	)

	# Violence term should be blocked
	var violence_result := adapter.check_text("Chce zabic potwora", child_6_8)
	_assert_true(
		violence_result.is_blocked(),
		"Violence term 'zabic' should be blocked"
	)
	_assert_true(
		violence_result.category == "violence",
		"Violence term should be categorized as 'violence'"
	)
	_assert_true(
		not violence_result.safe_alternative.is_empty(),
		"Blocked result should include a safe alternative"
	)

	# Weapon term should be blocked (whole-word matching)
	var weapon_result := adapter.check_text("Daj mi bron", child_6_8)
	_assert_true(
		weapon_result.is_blocked(),
		"Weapon term 'bron' should be blocked"
	)

	# Whole-word matching: "obrona" should NOT match "bron"
	var defense_result := adapter.check_text("Dobra obrona", child_6_8)
	_assert_true(
		defense_result.verdict == ModerationResult.Verdict.PASS,
		"'obrona' (defense) should NOT trigger 'bron' (weapon) false positive"
	)

	# Drug term should be blocked
	var drug_result := adapter.check_text("Dodaj alkohol do gry", child_6_8)
	_assert_true(
		drug_result.is_blocked(),
		"Drug term 'alkohol' should be blocked"
	)

	# Age-band specific: "straszny" blocked for CHILD_6_8 only
	var scary_child := adapter.check_text("Straszny zamek", child_6_8)
	_assert_true(
		scary_child.is_blocked(),
		"'straszny' should be blocked for CHILD_6_8 age band"
	)

	var scary_older := adapter.check_text("Straszny zamek", child_9_12)
	_assert_true(
		not scary_older.is_blocked(),
		"'straszny' should not be blocked for CHILD_9_12 age band"
	)

	# Empty text should pass
	var empty_result := adapter.check_text("", child_6_8)
	_assert_true(
		empty_result.verdict == ModerationResult.Verdict.PASS,
		"Empty text should pass moderation"
	)

	# Null age_band defaults to strictest
	var null_band := adapter.check_text("Straszny potwor", null)
	_assert_true(
		null_band.is_blocked(),
		"Null age_band should default to strictest (CHILD_6_8) filtering"
	)

	# Image moderation: empty data should be blocked
	var empty_image := adapter.check_image(PackedByteArray(), child_6_8)
	_assert_true(
		empty_image.is_blocked(),
		"Empty image data should be blocked"
	)

	# Image moderation: valid PNG magic bytes should pass
	var png_data := PackedByteArray()
	png_data.resize(256)
	png_data.fill(0)
	png_data[0] = 137
	png_data[1] = 80
	png_data[2] = 78
	png_data[3] = 71
	var png_result := adapter.check_image(png_data, child_6_8)
	_assert_true(
		png_result.verdict == ModerationResult.Verdict.PASS,
		"Valid PNG magic bytes should pass image moderation"
	)

	# Image moderation: invalid format should be blocked
	var bad_data := PackedByteArray()
	bad_data.resize(100)
	bad_data.fill(42)
	var bad_result := adapter.check_image(bad_data, child_6_8)
	_assert_true(
		bad_result.is_blocked(),
		"Invalid image format should be blocked"
	)
	_assert_true(
		bad_result.category == "format",
		"Invalid format should have 'format' category"
	)

	# Profanity should be blocked
	var profanity_result := adapter.check_text("Ale cholera co to jest", child_6_8)
	_assert_true(
		profanity_result.is_blocked(),
		"Profanity 'cholera' should be blocked"
	)

	# Punctuation should not prevent matching
	var punctuated := adapter.check_text("O nie, bron!", child_6_8)
	_assert_true(
		punctuated.is_blocked(),
		"Punctuation should not prevent weapon term detection"
	)

	return _build_result("LocalModerationAdapter")

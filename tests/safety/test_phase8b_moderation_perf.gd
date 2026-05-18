## Phase 8b performance test: 1000-message corpus moderated in under 100ms.
## Also verifies O(1) term lookup and MAX_MODERATION_TERMS cap enforcement.
extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var checks := 0

	var moderation := LocalModerationAdapter.new().setup("")
	var age := AgeBand.new(AgeBand.Band.CHILD_6_8)

	# ── Correctness: blocked terms still detected after rewrite ─────────────
	var blocked_cases: Array[Array] = [
		["chce zabic potwora", true],
		["daj mi bron", true],
		["zbuduj ladny domek", false],
		["photoreal portret", true],
		["fotorealistyczny portret", true],
		["selfie gracza", true],
		# Multi-word phrase regression (normalize mismatch fix + phrase-pass restore)
		["draw a realistic human", true],
		["portret czlowieka", true],
		["generate a human portrait", true],
		["realistyczny czlowiek", true],
		["styl photo-real prosze", true],
	]
	for pair in blocked_cases:
		checks += 1
		var result := moderation.check_text(str(pair[0]), age)
		var should_block: bool = bool(pair[1])
		if result.is_blocked() != should_block:
			failures.append(
				"Correctness: '%s' expected blocked=%s got blocked=%s" %
				[pair[0], should_block, result.is_blocked()]
			)

	# ── Performance: 1000 messages under 100ms ────────────────────────────
	var corpus: Array[String] = []
	for i in range(1000):
		match i % 10:
			0: corpus.append("zbuduj czerwony dom w polu")
			1: corpus.append("dodaj drzewo do mojego swiata")
			2: corpus.append("zmien kolor nieba na niebieskie")
			3: corpus.append("postaw mur wokol zamku")
			4: corpus.append("dodaj fontanne na srodku")
			5: corpus.append("chce latajace wyspy jak w bajce")
			6: corpus.append("stworz tajemnicza pieczare ze swiecacymi kamieniami")
			7: corpus.append("dodaj przyjazne zwierzeta do lasu")
			8: corpus.append("stwórz most laczacy dwie wiezyce")
			9: corpus.append("umies skarb w jaskini pod wodospadem")
	checks += 1
	var start_ms := Time.get_ticks_msec()
	for msg in corpus:
		moderation.check_text(msg, age)
	var elapsed_ms := Time.get_ticks_msec() - start_ms
	# Budget: 100ms for 1000 messages (loose; CI may vary)
	if elapsed_ms > 100:
		failures.append(
			"Performance: 1000 messages took %dms (budget: 100ms)" % elapsed_ms
		)
	else:
		print("  Perf: 1000 messages in %dms (budget: 100ms)" % elapsed_ms)

	# ── MAX_MODERATION_TERMS: flat dict never exceeds cap ────────────────────
	checks += 1
	var lookup_size: int = moderation._term_lookup.size() + moderation._phrase_lookup.size()
	if lookup_size > LocalModerationAdapter.MAX_MODERATION_TERMS:
		failures.append(
			"Term dict size %d exceeds MAX_MODERATION_TERMS=%d" %
			[lookup_size, LocalModerationAdapter.MAX_MODERATION_TERMS]
		)

	if failures.is_empty():
		print("[PASS] Phase8bModerationPerf (%d checks, %dms/1000msg)" % [checks, elapsed_ms])
		quit(0)
		return

	print("[FAIL] Phase8bModerationPerf")
	for item in failures:
		print("  - %s" % item)
	print("Checks: %d" % checks)
	quit(1)

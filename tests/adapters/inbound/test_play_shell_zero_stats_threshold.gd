## Wave C: Tests for play_shell zero-stats positive frame threshold fix.
## MUST criteria:
##   M1 - elapsed=300s, collectibles=0, achievements=0 → shows play.session.try_again_friend (not numeric)
##   M2 - elapsed=15s, collectibles=2, achievements=0 → numeric labels shown (NOT try_again_friend fallback)
##   M3 - elapsed=90s, collectibles=0, achievements=1 → numeric labels shown (achievements non-zero)
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_long_session_zero_stats_shows_encouragement()
	await _test_short_session_with_collectibles_shows_numeric()
	await _test_zero_collectibles_nonzero_achievements_shows_numeric()
	print("ALL_PLAY_SHELL_ZERO_STATS_THRESHOLD_TESTS: PASS")
	quit(0)


## M1 - long session (300s), zero stats → must show try_again_friend, not bare numbers
func _test_long_session_zero_stats_shows_encouragement() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_status := MockKidStatusReadModel.new()
	mock_status.collectibles = 0
	mock_status.achievements = 0
	mock_status.elapsed_seconds = 300
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, null, mock_status)
	shell.set_world_context("world_1")
	shell._on_session_ended()
	await process_frame
	if not mock_loc.queried_keys.has("play.session.try_again_friend"):
		print("FAIL M1: play.session.try_again_friend not queried for 300s zero-stats session, got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	# Must NOT show numeric stats labels
	if mock_loc.queried_keys.has("play.stats.collectibles"):
		print("FAIL M1: play.stats.collectibles was queried (numeric display) for zero-stats 300s session — should show encouragement only")
		shell.queue_free()
		quit(1)
		return
	print("PASS M1: long zero-stats session shows encouragement, not numeric display")
	shell.queue_free()


## M2 - short session (15s), collectibles=2 → numeric labels shown, NOT try_again_friend
func _test_short_session_with_collectibles_shows_numeric() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_status := MockKidStatusReadModel.new()
	mock_status.collectibles = 2
	mock_status.achievements = 0
	mock_status.elapsed_seconds = 15
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, null, mock_status)
	shell.set_world_context("world_1")
	shell._on_session_ended()
	await process_frame
	if not mock_loc.queried_keys.has("play.stats.collectibles"):
		print("FAIL M2: play.stats.collectibles not queried for session with 2 collectibles, got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	if mock_loc.queried_keys.has("play.session.try_again_friend"):
		print("FAIL M2: try_again_friend was shown when collectibles=2 (should show numeric), got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M2: session with collectibles shows numeric display, not encouragement")
	shell.queue_free()


## M3 - 90s session, collectibles=0, achievements=1 → numeric (not try_again_friend)
func _test_zero_collectibles_nonzero_achievements_shows_numeric() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_status := MockKidStatusReadModel.new()
	mock_status.collectibles = 0
	mock_status.achievements = 1
	mock_status.elapsed_seconds = 90
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, null, mock_status)
	shell.set_world_context("world_1")
	shell._on_session_ended()
	await process_frame
	if not mock_loc.queried_keys.has("play.stats.achievements"):
		print("FAIL M3: play.stats.achievements not queried for session with achievement=1, got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	if mock_loc.queried_keys.has("play.session.try_again_friend"):
		print("FAIL M3: try_again_friend shown when achievements=1 (should show numeric)")
		shell.queue_free()
		quit(1)
		return
	print("PASS M3: nonzero achievement shows numeric display")
	shell.queue_free()


class MockKidStatusReadModel extends KidStatusReadModel:
	var collectibles: int = 0
	var achievements: int = 0
	var elapsed_seconds: int = 0

	func get_project_status(project_id: String, profile_id: String) -> Dictionary:
		return {
			"project_id": project_id,
			"profile_id": profile_id,
			"collectibles_found": collectibles,
			"achievements_earned": achievements,
			"elapsed_seconds": elapsed_seconds,
			"progress_pct": 0,
		}


class MockLocalizationPolicy extends LocalizationPolicyPort:
	var queried_keys: Array[String] = []

	func translate(key: String) -> String:
		queried_keys.append(key)
		return key

	func is_term_safe(_term: String) -> bool:
		return true

	func get_preferred_term(term_key: String) -> String:
		return term_key

	func get_parent_term(term_key: String) -> String:
		return term_key

	func get_locale() -> String:
		return "pl-PL"

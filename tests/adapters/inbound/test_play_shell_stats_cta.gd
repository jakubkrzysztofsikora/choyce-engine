## Tests for PlayShell Phase 8f (real session stats) + Phase 9 (non-reader CTA)
## MUST criteria:
##   M1 - _show_session_end_screen uses real collectibles from KidStatusReadModel, not randi()
##   M2 - _show_session_end_screen uses real achievements from KidStatusReadModel, not randi()
##   M3 - _show_session_end_screen uses real elapsed time from session, not "~2 min"
##   M4 - zero stats (collectibles=0, achievements=0, elapsed<30s) shows _t("play.session.try_again_friend")
##   M5 - non-zero stats shows _t("play.stats.collectibles") label, not bare number
##   M6 - non-zero stats shows _t("play.stats.achievements") label
##   M7 - non-zero stats shows _t("play.stats.time") label
##   M8 - when no active world, shell exposes get_no_world_cta_button() returning a non-null Button
##   M9 - CTA button text uses _t("play.cta.create_world")
##   M10 - CTA button press navigates to create shell
##   M11 - PolishLocalizationPolicy has play.stats.* and play.session.try_again_friend keys
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_real_collectibles_used()
	await _test_real_achievements_used()
	await _test_real_time_used()
	await _test_zero_stats_shows_encouragement()
	await _test_nonzero_stats_shows_labels()
	await _test_no_world_cta_button_exists()
	await _test_cta_button_text_uses_key()
	await _test_cta_button_navigates_to_create()
	_test_localization_policy_has_stats_keys()
	print("ALL_PLAY_SHELL_STATS_CTA_TESTS: PASS")
	quit(0)


## M1+M2 - real collectibles and achievements from read model
func _test_real_collectibles_used() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_status := MockKidStatusReadModel.new()
	mock_status.collectibles = 7
	mock_status.achievements = 3
	mock_status.elapsed_seconds = 120
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, null, mock_status)
	shell.set_world_context("world_1")
	shell._on_session_ended()
	await process_frame
	if not mock_loc.queried_keys.has("play.stats.collectibles"):
		print("FAIL M1: play.stats.collectibles not queried (non-zero stats), got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M1: real collectibles label queried")
	shell.queue_free()


## M2 - achievements label queried
func _test_real_achievements_used() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_status := MockKidStatusReadModel.new()
	mock_status.collectibles = 2
	mock_status.achievements = 1
	mock_status.elapsed_seconds = 60
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, null, mock_status)
	shell.set_world_context("world_1")
	shell._on_session_ended()
	await process_frame
	if not mock_loc.queried_keys.has("play.stats.achievements"):
		print("FAIL M2: play.stats.achievements not queried, got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M2: achievements label queried")
	shell.queue_free()


## M3 - time label queried (not "~2 min")
func _test_real_time_used() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_status := MockKidStatusReadModel.new()
	mock_status.collectibles = 1
	mock_status.achievements = 0
	mock_status.elapsed_seconds = 90
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, null, mock_status)
	shell.set_world_context("world_1")
	shell._on_session_ended()
	await process_frame
	if not mock_loc.queried_keys.has("play.stats.time"):
		print("FAIL M3: play.stats.time not queried, got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M3: time label queried")
	shell.queue_free()


## M4 - zero stats with elapsed < 30s shows try_again_friend key
func _test_zero_stats_shows_encouragement() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_status := MockKidStatusReadModel.new()
	mock_status.collectibles = 0
	mock_status.achievements = 0
	mock_status.elapsed_seconds = 10
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, null, mock_status)
	shell.set_world_context("world_1")
	shell._on_session_ended()
	await process_frame
	if not mock_loc.queried_keys.has("play.session.try_again_friend"):
		print("FAIL M4: play.session.try_again_friend not queried for zero stats, got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M4: try_again_friend shown for zero stats")
	shell.queue_free()


## M5+M6+M7 - non-zero stats show all three stat labels
func _test_nonzero_stats_shows_labels() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_status := MockKidStatusReadModel.new()
	mock_status.collectibles = 3
	mock_status.achievements = 1
	mock_status.elapsed_seconds = 180
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, null, mock_status)
	shell.set_world_context("world_1")
	shell._on_session_ended()
	await process_frame
	var required := ["play.stats.collectibles", "play.stats.achievements", "play.stats.time"]
	for key in required:
		if not mock_loc.queried_keys.has(key):
			print("FAIL M5-M7: '%s' not queried for non-zero stats, got: %s" % [key, str(mock_loc.queried_keys)])
			shell.queue_free()
			quit(1)
			return
	print("PASS M5-M7: all stat labels queried for non-zero stats")
	shell.queue_free()


## M8 - no active world → shell has a CTA button accessible via get_no_world_cta_button()
func _test_no_world_cta_button_exists() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, null)
	# No world context set → button should appear
	shell._show_no_world_cta()
	await process_frame
	var btn := shell.get_no_world_cta_button()
	if btn == null:
		print("FAIL M8: get_no_world_cta_button() returned null")
		shell.queue_free()
		quit(1)
		return
	if not (btn is Button):
		print("FAIL M8: get_no_world_cta_button() is not a Button, got %s" % str(btn))
		shell.queue_free()
		quit(1)
		return
	print("PASS M8: CTA button present")
	shell.queue_free()


## M9 - CTA button text queries _t("play.cta.create_world")
func _test_cta_button_text_uses_key() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, null)
	shell._show_no_world_cta()
	await process_frame
	if not mock_loc.queried_keys.has("play.cta.create_world"):
		print("FAIL M9: play.cta.create_world not queried, got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M9: CTA button text uses play.cta.create_world key")
	shell.queue_free()


## M10 - CTA button press navigates to create shell
func _test_cta_button_navigates_to_create() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_nav := MockNavigator.new()
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(mock_nav, profile, mock_loc, null)
	shell._show_no_world_cta()
	await process_frame
	var btn := shell.get_no_world_cta_button()
	if btn == null:
		print("FAIL M10: no CTA button")
		shell.queue_free()
		quit(1)
		return
	btn.pressed.emit()
	await process_frame
	if mock_nav.last_shown != "create":
		print("FAIL M10: expected navigate to 'create', got '%s'" % str(mock_nav.last_shown))
		shell.queue_free()
		quit(1)
		return
	print("PASS M10: CTA navigates to create")
	shell.queue_free()


## M11 - PolishLocalizationPolicy has play.stats.* and try_again_friend
func _test_localization_policy_has_stats_keys() -> void:
	var policy := PolishLocalizationPolicy.new()
	var required_keys: Array[String] = [
		"play.stats.collectibles",
		"play.stats.achievements",
		"play.stats.time",
		"play.session.try_again_friend",
		"play.cta.create_world",
		"play.cta.create_world_voice",
	]
	for key in required_keys:
		var val := policy.translate(key)
		if val == key:
			print("FAIL M11: PolishLocalizationPolicy missing key '%s'" % key)
			quit(1)
			return
	print("PASS M11: PolishLocalizationPolicy has all play.stats.* keys")


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


class MockNavigator extends ShellNavigator:
	var last_shown: String = ""

	func show_shell(shell_id: String) -> void:
		last_shown = shell_id


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

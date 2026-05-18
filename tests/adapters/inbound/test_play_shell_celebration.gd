## Tests for PlayShell celebration overlay (confetti burst + tweened counters).
## MUST criteria:
##   M1 - show_celebration method exists on PlayShell
##   M2 - CelebrationLayer node is present and starts hidden
##   M3 - show_celebration makes CelebrationLayer visible
##   M4 - hide_celebration hides CelebrationLayer
##   M5 - show_celebration with zero stats queries play.session.try_again_friend
##   M6 - show_celebration with non-zero stats queries play.session.celebration_title
##   M7 - PolishLocalizationPolicy has play.session.celebration_title key
##   M8 - PolishLocalizationPolicy has play.session.collectibles_label key
##   M9 - PolishLocalizationPolicy has play.session.achievements_label key
##   M10 - PolishLocalizationPolicy has play.session.time_label key
##   M11 - PolishLocalizationPolicy has play.celebration.close key
##   M12 - _show_session_end_screen routes through show_celebration (not old static label only)
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_show_celebration_method_exists()
	await _test_celebration_layer_starts_hidden()
	await _test_show_celebration_makes_layer_visible()
	await _test_hide_celebration_hides_layer()
	await _test_zero_stats_queries_try_again()
	await _test_nonzero_stats_queries_celebration_title()
	_test_localization_has_celebration_title()
	_test_localization_has_collectibles_label()
	_test_localization_has_achievements_label()
	_test_localization_has_time_label()
	_test_localization_has_close_key()
	await _test_session_end_routes_to_celebration()
	print("ALL_PLAY_SHELL_CELEBRATION_TESTS: PASS")
	quit(0)


## M1 - show_celebration method exists
func _test_show_celebration_method_exists() -> void:
	var shell := PlayShell.new()
	if not shell.has_method("show_celebration"):
		print("FAIL M1: show_celebration method missing from PlayShell")
		shell.free()
		quit(1)
		return
	shell.free()
	print("PASS M1: show_celebration method exists")


## M2 - CelebrationLayer starts hidden
func _test_celebration_layer_starts_hidden() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var layer := shell.get_node_or_null("CelebrationLayer")
	if layer == null:
		print("FAIL M2: CelebrationLayer node not found")
		shell.queue_free()
		quit(1)
		return
	if layer.visible:
		print("FAIL M2: CelebrationLayer should start hidden")
		shell.queue_free()
		quit(1)
		return
	print("PASS M2: CelebrationLayer starts hidden")
	shell.queue_free()


## M3 - show_celebration makes layer visible
func _test_show_celebration_makes_layer_visible() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	shell.setup(null, PlayerProfile.new("kid_1", PlayerProfile.Role.KID), mock_loc, null)
	shell.show_celebration({"collectibles": 3, "achievements": 1, "elapsed_seconds": 90})
	await process_frame
	var layer := shell.get_node_or_null("CelebrationLayer")
	if layer == null or not layer.visible:
		print("FAIL M3: CelebrationLayer not visible after show_celebration")
		shell.queue_free()
		quit(1)
		return
	print("PASS M3: CelebrationLayer visible after show_celebration")
	shell.queue_free()


## M4 - hide_celebration hides layer
func _test_hide_celebration_hides_layer() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	shell.setup(null, PlayerProfile.new("kid_1", PlayerProfile.Role.KID), mock_loc, null)
	shell.show_celebration({"collectibles": 1, "achievements": 0, "elapsed_seconds": 30})
	await process_frame
	shell.hide_celebration()
	await process_frame
	var layer := shell.get_node_or_null("CelebrationLayer")
	if layer == null or layer.visible:
		print("FAIL M4: CelebrationLayer still visible after hide_celebration")
		shell.queue_free()
		quit(1)
		return
	print("PASS M4: CelebrationLayer hidden after hide_celebration")
	shell.queue_free()


## M5 - zero stats → queries play.session.try_again_friend
func _test_zero_stats_queries_try_again() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	shell.setup(null, PlayerProfile.new("kid_1", PlayerProfile.Role.KID), mock_loc, null)
	shell.show_celebration({"collectibles": 0, "achievements": 0, "elapsed_seconds": 0})
	await process_frame
	if not mock_loc.queried_keys.has("play.session.try_again_friend"):
		print("FAIL M5: play.session.try_again_friend not queried for zero stats, got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M5: try_again_friend queried for zero stats")
	shell.queue_free()


## M6 - non-zero stats → queries play.session.celebration_title
func _test_nonzero_stats_queries_celebration_title() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	shell.setup(null, PlayerProfile.new("kid_1", PlayerProfile.Role.KID), mock_loc, null)
	shell.show_celebration({"collectibles": 2, "achievements": 1, "elapsed_seconds": 60})
	await process_frame
	if not mock_loc.queried_keys.has("play.session.celebration_title"):
		print("FAIL M6: play.session.celebration_title not queried for non-zero stats, got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M6: celebration_title queried for non-zero stats")
	shell.queue_free()


## M7 - PolishLocalizationPolicy has play.session.celebration_title
func _test_localization_has_celebration_title() -> void:
	var policy := PolishLocalizationPolicy.new()
	var val := policy.translate("play.session.celebration_title")
	if val == "play.session.celebration_title":
		print("FAIL M7: play.session.celebration_title missing from PolishLocalizationPolicy")
		quit(1)
		return
	print("PASS M7: play.session.celebration_title present: '%s'" % val)


## M8 - PolishLocalizationPolicy has play.session.collectibles_label
func _test_localization_has_collectibles_label() -> void:
	var policy := PolishLocalizationPolicy.new()
	var val := policy.translate("play.session.collectibles_label")
	if val == "play.session.collectibles_label":
		print("FAIL M8: play.session.collectibles_label missing")
		quit(1)
		return
	print("PASS M8: play.session.collectibles_label present: '%s'" % val)


## M9 - PolishLocalizationPolicy has play.session.achievements_label
func _test_localization_has_achievements_label() -> void:
	var policy := PolishLocalizationPolicy.new()
	var val := policy.translate("play.session.achievements_label")
	if val == "play.session.achievements_label":
		print("FAIL M9: play.session.achievements_label missing")
		quit(1)
		return
	print("PASS M9: play.session.achievements_label present: '%s'" % val)


## M10 - PolishLocalizationPolicy has play.session.time_label
func _test_localization_has_time_label() -> void:
	var policy := PolishLocalizationPolicy.new()
	var val := policy.translate("play.session.time_label")
	if val == "play.session.time_label":
		print("FAIL M10: play.session.time_label missing")
		quit(1)
		return
	print("PASS M10: play.session.time_label present: '%s'" % val)


## M11 - PolishLocalizationPolicy has play.celebration.close
func _test_localization_has_close_key() -> void:
	var policy := PolishLocalizationPolicy.new()
	var val := policy.translate("play.celebration.close")
	if val == "play.celebration.close":
		print("FAIL M11: play.celebration.close missing")
		quit(1)
		return
	print("PASS M11: play.celebration.close present: '%s'" % val)


## M12 - _show_session_end_screen routes through show_celebration
func _test_session_end_routes_to_celebration() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_status := MockKidStatusReadModel.new()
	mock_status.collectibles = 5
	mock_status.achievements = 2
	mock_status.elapsed_seconds = 150
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, null, mock_status)
	shell.set_world_context("world_1")
	shell._on_session_ended()
	await process_frame
	var layer := shell.get_node_or_null("CelebrationLayer")
	if layer == null or not layer.visible:
		print("FAIL M12: CelebrationLayer not visible after _on_session_ended with non-zero stats")
		shell.queue_free()
		quit(1)
		return
	print("PASS M12: CelebrationLayer visible after session end with non-zero stats")
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

## Tests for PlayShell Phase 4a-2: Polish string extraction via _t()
## MUST criteria:
##   M1 - _launch_playtest with empty world_id shows _t("play.error.no_world"), not hardcoded Polish
##   M2 - _launch_playtest with null world shows _t("play.error.load_failed"), not hardcoded Polish
##   M3 - _launch_playtest with empty scene_nodes shows _t("play.error.create_first"), not hardcoded Polish
##   M4 - _launch_playtest with null session shows _t("play.error.start_failed"), not hardcoded Polish
##   M5 - _on_session_ended sets info via _t("play.session.ended"), not hardcoded Polish
##   M6 - quest tracker empty state uses _t("play.quests.empty"), not hardcoded Polish
##   M7 - _refresh_labels uses _t("play.quest.title") for quest section heading
##   M8 - _refresh_labels uses _t("play.session.close") for close button
##   M9 - launched session info uses _t("play.mode.coop") and _t("play.mode.solo")
##   M10 - PolishLocalizationPolicy._translations contains all play.* keys
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_no_world_error_uses_key()
	await _test_load_failed_uses_key()
	await _test_create_first_uses_key()
	await _test_start_failed_uses_key()
	await _test_session_ended_uses_key()
	await _test_quests_empty_uses_key()
	await _test_quest_title_uses_key()
	await _test_session_close_uses_key()
	await _test_mode_coop_uses_key()
	await _test_mode_solo_uses_key()
	_test_localization_policy_has_play_keys()
	print("ALL_PLAY_SHELL_L10N_TESTS: PASS")
	quit(0)


## M1 - empty world_id sets info to _t("play.error.no_world")
func _test_no_world_error_uses_key() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_port := MockRunPlaytestPort.new()
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, mock_port)
	# No set_world_context call → _active_world_id is empty
	shell._launch_playtest(false)
	await process_frame
	if not mock_loc.queried_keys.has("play.error.no_world"):
		print("FAIL M1: play.error.no_world not queried, got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M1: play.error.no_world queried")
	shell.queue_free()


## M2 - world callback returns null → _t("play.error.load_failed")
func _test_load_failed_uses_key() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_port := MockRunPlaytestPort.new()
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, mock_port, null, func() -> World: return null)
	shell.set_world_context("world_1")
	shell._launch_playtest(false)
	await process_frame
	if not mock_loc.queried_keys.has("play.error.load_failed"):
		print("FAIL M2: play.error.load_failed not queried, got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M2: play.error.load_failed queried")
	shell.queue_free()


## M3 - world has empty scene_nodes → _t("play.error.create_first")
func _test_create_first_uses_key() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_port := MockRunPlaytestPort.new()
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	var empty_world := World.new("world_1", "Test World")
	# scene_nodes is empty by default
	shell.setup(null, profile, mock_loc, mock_port, null, func() -> World: return empty_world)
	shell.set_world_context("world_1")
	shell._launch_playtest(false)
	await process_frame
	if not mock_loc.queried_keys.has("play.error.create_first"):
		print("FAIL M3: play.error.create_first not queried, got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M3: play.error.create_first queried")
	shell.queue_free()


## M4 - port returns null session → _t("play.error.start_failed")
func _test_start_failed_uses_key() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_port := MockRunPlaytestPort.new()
	mock_port.return_null = true
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	var world := World.new("world_1", "Test World")
	world.scene_nodes.append({"type": "cube"})
	shell.setup(null, profile, mock_loc, mock_port, null, func() -> World: return world)
	shell.set_world_context("world_1")
	shell._launch_playtest(false)
	await process_frame
	if not mock_loc.queried_keys.has("play.error.start_failed"):
		print("FAIL M4: play.error.start_failed not queried, got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M4: play.error.start_failed queried")
	shell.queue_free()


## M5 - _on_session_ended queries _t("play.session.ended")
func _test_session_ended_uses_key() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, null)
	shell._on_session_ended()
	await process_frame
	if not mock_loc.queried_keys.has("play.session.ended"):
		print("FAIL M5: play.session.ended not queried, got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M5: play.session.ended queried")
	shell.queue_free()


## M6 - quest tracker empty state queries _t("play.quests.empty")
func _test_quests_empty_uses_key() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	# Provide a world callback that returns a world with no quests
	var world := World.new("world_1", "Test World")
	shell.setup(null, profile, mock_loc, null, null, func() -> World: return world)
	shell.set_world_context("world_1")
	shell._refresh_quest_tracker()
	await process_frame
	if not mock_loc.queried_keys.has("play.quests.empty"):
		print("FAIL M6: play.quests.empty not queried, got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M6: play.quests.empty queried")
	shell.queue_free()


## M7 - _refresh_labels queries _t("play.quest.title")
func _test_quest_title_uses_key() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, null)
	shell._refresh_labels()
	await process_frame
	if not mock_loc.queried_keys.has("play.quest.title"):
		print("FAIL M7: play.quest.title not queried, got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M7: play.quest.title queried")
	shell.queue_free()


## M8 - _refresh_labels queries _t("play.session.close")
func _test_session_close_uses_key() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, null)
	shell._refresh_labels()
	await process_frame
	if not mock_loc.queried_keys.has("play.session.close"):
		print("FAIL M8: play.session.close not queried, got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M8: play.session.close queried")
	shell.queue_free()


## M9 - coop launch queries _t("play.mode.coop"), solo queries _t("play.mode.solo")
func _test_mode_coop_uses_key() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_port := MockRunPlaytestPort.new()
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	var world := World.new("world_1", "Test World")
	world.scene_nodes.append({"type": "cube"})
	shell.setup(null, profile, mock_loc, mock_port, null, func() -> World: return world)
	shell.set_world_context("world_1")
	shell._launch_playtest(true)
	await process_frame
	if not mock_loc.queried_keys.has("play.mode.coop"):
		print("FAIL M9: play.mode.coop not queried (coop launch), got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M9: play.mode.coop queried for coop launch")
	shell.queue_free()


func _test_mode_solo_uses_key() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_port := MockRunPlaytestPort.new()
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	var world := World.new("world_1", "Test World")
	world.scene_nodes.append({"type": "cube"})
	shell.setup(null, profile, mock_loc, mock_port, null, func() -> World: return world)
	shell.set_world_context("world_1")
	shell._launch_playtest(false)
	await process_frame
	if not mock_loc.queried_keys.has("play.mode.solo"):
		print("FAIL M9: play.mode.solo not queried (solo launch), got: %s" % str(mock_loc.queried_keys))
		shell.queue_free()
		quit(1)
		return
	print("PASS M9: play.mode.solo queried for solo launch")
	shell.queue_free()


## M10 - PolishLocalizationPolicy has all play.* keys registered
func _test_localization_policy_has_play_keys() -> void:
	var policy := PolishLocalizationPolicy.new()
	var required_keys: Array[String] = [
		"play.error.no_world",
		"play.error.load_failed",
		"play.error.create_first",
		"play.error.start_failed",
		"play.session.ended",
		"play.session.close",
		"play.quests.empty",
		"play.quest.title",
		"play.quest.default_title",
		"play.mode.coop",
		"play.mode.solo",
		"play.guest.name",
		"play.session.started",
		"play.cta.create_world",
	]
	for key in required_keys:
		var val := policy.translate(key)
		if val == key:
			print("FAIL M10: PolishLocalizationPolicy missing key '%s'" % key)
			quit(1)
			return
	print("PASS M10: PolishLocalizationPolicy has all play.* keys")


class MockRunPlaytestPort extends RunPlaytestPort:
	var return_null: bool = false

	func execute(_world_id: String, _players: Array) -> Session:
		if return_null:
			return null
		var s := Session.new("mock_session_1", _world_id)
		return s


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

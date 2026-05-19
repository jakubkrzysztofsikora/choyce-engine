## Tests for OnboardingOverlay: Phase 4a-4 (Polish l10n) + Phase 4c (skip UX) + TTS port.
## MUST criteria tested here:
##   M1 - celebrate_completion uses _t("onboarding.celebrate") not hardcoded string
##   M2 - mouse_filter is MOUSE_FILTER_PASS (not MOUSE_FILTER_STOP)
##   M3 - auto-dismiss timer starts with 30s duration
##   M4 - "Pomij" skip button present and visible
##   M5 - skip button emits advance_requested when pressed
##   M6 - TTS prompt timer configured at 5s
##   M7 - _on_tts_prompt() invokes tts.speak() when port injected and available
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_mouse_filter_is_pass()
	await _test_skip_button_present()
	await _test_skip_button_emits_advance()
	await _test_auto_dismiss_timer_30s()
	await _test_celebration_uses_localized_key()
	await _test_tts_prompt_at_5s()
	await _test_tts_speak_invoked_when_port_available()
	print("ALL_ONBOARDING_OVERLAY_TESTS: PASS")
	quit(0)


## M2 - mouse_filter must be MOUSE_FILTER_PASS
func _test_mouse_filter_is_pass() -> void:
	var overlay := OnboardingOverlay.new()
	get_root().add_child(overlay)
	await process_frame
	if overlay.mouse_filter != Control.MOUSE_FILTER_PASS:
		print("FAIL M2: mouse_filter should be MOUSE_FILTER_PASS, got %d" % overlay.mouse_filter)
		overlay.queue_free()
		quit(1)
		return
	print("PASS M2: mouse_filter is MOUSE_FILTER_PASS")
	overlay.queue_free()


## M4 - skip button present and visible
func _test_skip_button_present() -> void:
	var overlay := OnboardingOverlay.new()
	get_root().add_child(overlay)
	await process_frame
	var btn := overlay.get_skip_button()
	if btn == null:
		print("FAIL M4: get_skip_button() returned null")
		overlay.queue_free()
		quit(1)
		return
	if not btn.visible:
		print("FAIL M4: skip button is not visible")
		overlay.queue_free()
		quit(1)
		return
	print("PASS M4: skip button present and visible")
	overlay.queue_free()


## M5 - skip button press emits advance_requested
func _test_skip_button_emits_advance() -> void:
	var overlay := OnboardingOverlay.new()
	get_root().add_child(overlay)
	await process_frame
	var fired := [false]
	overlay.advance_requested.connect(func(): fired[0] = true)
	var btn := overlay.get_skip_button()
	if btn == null:
		print("FAIL M5: no skip button")
		overlay.queue_free()
		quit(1)
		return
	btn.emit_signal("pressed")
	await process_frame
	await process_frame
	if not fired[0]:
		print("FAIL M5: advance_requested not emitted on skip press")
		overlay.queue_free()
		quit(1)
		return
	print("PASS M5: skip press emits advance_requested")
	overlay.queue_free()


## M3 - auto-dismiss timer initialised to 30s
func _test_auto_dismiss_timer_30s() -> void:
	var overlay := OnboardingOverlay.new()
	get_root().add_child(overlay)
	await process_frame
	var timer := overlay.get_auto_dismiss_timer()
	if timer == null:
		print("FAIL M3: get_auto_dismiss_timer() returned null")
		overlay.queue_free()
		quit(1)
		return
	if timer.wait_time != 30.0:
		print("FAIL M3: auto-dismiss wait_time should be 30.0, got %f" % timer.wait_time)
		overlay.queue_free()
		quit(1)
		return
	print("PASS M3: auto-dismiss timer is 30s")
	overlay.queue_free()


## M1 - celebrate_completion uses localized key not hardcoded Polish
func _test_celebration_uses_localized_key() -> void:
	var overlay := OnboardingOverlay.new()
	get_root().add_child(overlay)
	await process_frame
	# inject a mock localization that records which key was requested
	var mock_loc := MockLocalizationPolicy.new()
	overlay.setup_localization(mock_loc)
	overlay.celebrate_completion()
	await process_frame
	if not mock_loc.queried_keys.has("onboarding.celebrate"):
		print("FAIL M1: celebrate_completion did not query 'onboarding.celebrate' key, got: %s" % str(mock_loc.queried_keys))
		overlay.queue_free()
		quit(1)
		return
	print("PASS M1: celebrate_completion queries localization key")
	overlay.queue_free()


## M6 - TTS prompt at 5s: overlay exposes get_tts_prompt_timer() with 5s wait_time
func _test_tts_prompt_at_5s() -> void:
	var overlay := OnboardingOverlay.new()
	get_root().add_child(overlay)
	await process_frame
	var timer := overlay.get_tts_prompt_timer()
	if timer == null:
		print("FAIL M6: get_tts_prompt_timer() returned null")
		overlay.queue_free()
		quit(1)
		return
	if timer.wait_time != 5.0:
		print("FAIL M6: TTS prompt timer should be 5.0s, got %f" % timer.wait_time)
		overlay.queue_free()
		quit(1)
		return
	print("PASS M6: TTS prompt timer is 5s")
	overlay.queue_free()


## M7 - setup_tts() injects port; _on_tts_prompt() calls speak() when available
func _test_tts_speak_invoked_when_port_available() -> void:
	var overlay := OnboardingOverlay.new()
	get_root().add_child(overlay)
	await process_frame

	var mock_tts := MockTTSPort.new()
	overlay.setup_tts(mock_tts)

	# Simulate the TTS prompt timer firing by calling the handler directly.
	overlay._on_tts_prompt()
	await process_frame

	if mock_tts.speak_calls.size() == 0:
		print("FAIL M7: speak() not called when TTS port available")
		overlay.queue_free()
		quit(1)
		return
	if mock_tts.speak_calls[0] != "onboarding.tts_prompt":
		print("FAIL M7: speak() called with wrong text '%s'" % mock_tts.speak_calls[0])
		overlay.queue_free()
		quit(1)
		return
	print("PASS M7: speak() invoked with onboarding.tts_prompt key")
	overlay.queue_free()


class MockTTSPort extends VoicePromptPort:
	var speak_calls: Array[String] = []

	func speak(text: String, _locale: String = "pl-PL") -> void:
		speak_calls.append(text)

	func is_available() -> bool:
		return true

	func cancel() -> void:
		pass


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

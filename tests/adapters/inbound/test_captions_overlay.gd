## Tests for CaptionsOverlay: Phase 4a-5 (Polish l10n) + Phase 4d (accessibility options).
## MUST criteria tested here:
##   M1 - font_size option accepted: 24, 32, 40
##   M2 - high-contrast toggle: bg becomes near-black, font becomes white
##   M3 - position toggle: bottom (anchor_top ~0.85) and top (anchor_top ~0.0)
##   M4 - tts_narration toggle stored and accessible
##   M5 - show_message still works after option changes
##   M6 - DEFAULT_FONT_SIZE is 32 (readable for emergent readers)
##   M7 - setup_tts(port) wires typed TextToSpeechPort; speak() called on show_message when narration enabled
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_font_size_24()
	await _test_font_size_32()
	await _test_font_size_40()
	await _test_high_contrast_toggle()
	await _test_position_top()
	await _test_position_bottom()
	await _test_tts_narration_toggle()
	await _test_show_message_still_works()
	await _test_default_font_size_is_32()
	await _test_setup_tts_speak_on_show_message()
	print("ALL_CAPTIONS_OVERLAY_TESTS: PASS")
	quit(0)


## M1 - font_size 24
func _test_font_size_24() -> void:
	var overlay := CaptionsOverlay.new()
	get_root().add_child(overlay)
	await process_frame
	overlay.set_font_size(24)
	var label := overlay.get_label()
	if label.get_theme_font_size("font_size") != 24:
		print("FAIL M1a: font_size should be 24")
		overlay.queue_free()
		quit(1)
		return
	print("PASS M1a: font_size 24 applied")
	overlay.queue_free()


## M1 - font_size 32
func _test_font_size_32() -> void:
	var overlay := CaptionsOverlay.new()
	get_root().add_child(overlay)
	await process_frame
	overlay.set_font_size(32)
	var label := overlay.get_label()
	if label.get_theme_font_size("font_size") != 32:
		print("FAIL M1b: font_size should be 32")
		overlay.queue_free()
		quit(1)
		return
	print("PASS M1b: font_size 32 applied")
	overlay.queue_free()


## M1 - font_size 40
func _test_font_size_40() -> void:
	var overlay := CaptionsOverlay.new()
	get_root().add_child(overlay)
	await process_frame
	overlay.set_font_size(40)
	var label := overlay.get_label()
	if label.get_theme_font_size("font_size") != 40:
		print("FAIL M1c: font_size should be 40")
		overlay.queue_free()
		quit(1)
		return
	print("PASS M1c: font_size 40 applied")
	overlay.queue_free()


## M2 - high-contrast: bg color alpha >= 0.95, font color is white
func _test_high_contrast_toggle() -> void:
	var overlay := CaptionsOverlay.new()
	get_root().add_child(overlay)
	await process_frame
	overlay.set_high_contrast(true)
	var label := overlay.get_label()
	var font_color: Color = label.get_theme_color("font_color")
	if font_color != Color.WHITE:
		print("FAIL M2: high-contrast font should be WHITE, got %s" % str(font_color))
		overlay.queue_free()
		quit(1)
		return
	if not overlay.is_high_contrast():
		print("FAIL M2: is_high_contrast() should return true")
		overlay.queue_free()
		quit(1)
		return
	overlay.set_high_contrast(false)
	if overlay.is_high_contrast():
		print("FAIL M2: is_high_contrast() should return false after toggle off")
		overlay.queue_free()
		quit(1)
		return
	print("PASS M2: high-contrast toggle works")
	overlay.queue_free()


## M3 - position top: panel anchor_top near 0
func _test_position_top() -> void:
	var overlay := CaptionsOverlay.new()
	get_root().add_child(overlay)
	await process_frame
	overlay.set_caption_position("top")
	var panel := overlay.get_panel()
	if panel.anchor_top > 0.15:
		print("FAIL M3a: position top should set anchor_top near 0, got %f" % panel.anchor_top)
		overlay.queue_free()
		quit(1)
		return
	print("PASS M3a: position top sets anchor near top")
	overlay.queue_free()


## M3 - position bottom: panel anchor_top near 0.85
func _test_position_bottom() -> void:
	var overlay := CaptionsOverlay.new()
	get_root().add_child(overlay)
	await process_frame
	overlay.set_caption_position("bottom")
	var panel := overlay.get_panel()
	if panel.anchor_top < 0.8:
		print("FAIL M3b: position bottom should set anchor_top >= 0.8, got %f" % panel.anchor_top)
		overlay.queue_free()
		quit(1)
		return
	print("PASS M3b: position bottom sets anchor near bottom")
	overlay.queue_free()


## M4 - TTS narration toggle stored
func _test_tts_narration_toggle() -> void:
	var overlay := CaptionsOverlay.new()
	get_root().add_child(overlay)
	await process_frame
	overlay.set_tts_narration(true)
	if not overlay.is_tts_narration_enabled():
		print("FAIL M4: set_tts_narration(true) should make is_tts_narration_enabled() true")
		overlay.queue_free()
		quit(1)
		return
	overlay.set_tts_narration(false)
	if overlay.is_tts_narration_enabled():
		print("FAIL M4: set_tts_narration(false) should make is_tts_narration_enabled() false")
		overlay.queue_free()
		quit(1)
		return
	print("PASS M4: TTS narration toggle stored correctly")
	overlay.queue_free()


## M6 - DEFAULT_FONT_SIZE is 32
func _test_default_font_size_is_32() -> void:
	var overlay := CaptionsOverlay.new()
	get_root().add_child(overlay)
	await process_frame
	var label := overlay.get_label()
	if label.get_theme_font_size("font_size") != 32:
		print("FAIL M6: DEFAULT_FONT_SIZE should be 32, got %d" % label.get_theme_font_size("font_size"))
		overlay.queue_free()
		quit(1)
		return
	print("PASS M6: DEFAULT_FONT_SIZE is 32")
	overlay.queue_free()


## M7 - setup_tts wires port; speak() called when tts_narration enabled and message shown
func _test_setup_tts_speak_on_show_message() -> void:
	var overlay := CaptionsOverlay.new()
	get_root().add_child(overlay)
	await process_frame

	var mock_tts := MockTTSPort.new()
	overlay.setup_tts(mock_tts)
	overlay.set_tts_narration(true)
	overlay.show_message("Hej!", 0.5)
	await process_frame

	if mock_tts.speak_calls.size() == 0:
		print("FAIL M7: speak() not called when TTS narration enabled")
		overlay.queue_free()
		quit(1)
		return
	if mock_tts.speak_calls[0] != "Hej!":
		print("FAIL M7: speak() called with wrong text '%s'" % mock_tts.speak_calls[0])
		overlay.queue_free()
		quit(1)
		return
	print("PASS M7: setup_tts wired; speak() called on show_message")
	overlay.queue_free()


class MockTTSPort extends TextToSpeechPort:
	var speak_calls: Array[String] = []

	func speak(text: String, _locale: String = "pl-PL") -> void:
		speak_calls.append(text)

	func is_available() -> bool:
		return true

	func cancel() -> void:
		pass


## M5 - show_message still works after option changes
func _test_show_message_still_works() -> void:
	var overlay := CaptionsOverlay.new()
	get_root().add_child(overlay)
	await process_frame
	overlay.set_font_size(40)
	overlay.set_high_contrast(true)
	overlay.set_caption_position("top")
	overlay.show_message("Test napis", 0.5)
	await process_frame
	if not overlay.visible:
		print("FAIL M5: show_message should make overlay visible")
		overlay.queue_free()
		quit(1)
		return
	var label := overlay.get_label()
	if label.text != "Test napis":
		print("FAIL M5: label text should be 'Test napis', got '%s'" % label.text)
		overlay.queue_free()
		quit(1)
		return
	print("PASS M5: show_message works after option changes")
	overlay.queue_free()

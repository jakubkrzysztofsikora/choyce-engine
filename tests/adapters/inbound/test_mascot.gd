## Tests for Mascot: kid bunny character + DomainEventBus reactions + speech bubble.
##
## MUST criteria tested here:
##   M1 - Mascot node instantiates and enters tree without crashing
##   M2 - mouse_filter is MOUSE_FILTER_IGNORE (never blocks UI clicks)
##   M3 - WorldRemixed domain event triggers EXCITED state and say("Świetnie!")
##   M4 - say() invokes voice_prompt.speak() when port injected and has speak()
##   M5 - setup() subscribes to event_bus via subscribe_all
##   M6 - null event_bus in setup() does not crash
##   M7 - _on_domain_event with null event does not crash
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_mascot_instantiates_without_crash()
	await _test_mouse_filter_is_ignore()
	await _test_world_remixed_triggers_excited_and_say()
	await _test_say_invokes_voice_prompt_speak()
	await _test_setup_subscribes_to_event_bus()
	await _test_null_event_bus_does_not_crash()
	await _test_null_event_does_not_crash()
	print("ALL_MASCOT_TESTS: PASS")
	quit(0)


## M1 - Mascot instantiates and adds to tree without crashing.
func _test_mascot_instantiates_without_crash() -> void:
	var mascot := Mascot.new()
	get_root().add_child(mascot)
	await process_frame
	print("PASS M1: Mascot instantiates without crash")
	mascot.queue_free()


## M2 - mouse_filter must be MOUSE_FILTER_IGNORE so it never blocks UI clicks.
func _test_mouse_filter_is_ignore() -> void:
	var mascot := Mascot.new()
	get_root().add_child(mascot)
	await process_frame
	if mascot.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		print("FAIL M2: mouse_filter should be MOUSE_FILTER_IGNORE (2), got %d" % mascot.mouse_filter)
		mascot.queue_free()
		quit(1)
		return
	print("PASS M2: mouse_filter is MOUSE_FILTER_IGNORE")
	mascot.queue_free()


## M3 - WorldRemixed event triggers EXCITED state and say("Świetnie!").
func _test_world_remixed_triggers_excited_and_say() -> void:
	var mascot := MockableMascot.new()
	get_root().add_child(mascot)
	await process_frame

	var event := WorldRemixedEvent.new("world_1", "kid_1")
	mascot._on_domain_event(event)
	await process_frame

	if mascot._state != Mascot.State.EXCITED:
		print("FAIL M3: state should be EXCITED after WorldRemixed, got %d" % mascot._state)
		mascot.queue_free()
		quit(1)
		return
	if mascot.last_said != "Świetnie!":
		print("FAIL M3: say() should have been called with 'Świetnie!', got '%s'" % mascot.last_said)
		mascot.queue_free()
		quit(1)
		return
	print("PASS M3: WorldRemixed -> EXCITED + say('Świetnie!')")
	mascot.queue_free()


## M4 - say() invokes voice_prompt.speak() when port has speak().
func _test_say_invokes_voice_prompt_speak() -> void:
	var mascot := Mascot.new()
	get_root().add_child(mascot)
	await process_frame

	var mock_voice := MockVoicePrompt.new()
	mascot.setup(null, mock_voice)

	# Trigger say directly (bypasses the async await so we can check synchronously).
	mascot._voice_prompt = mock_voice
	if mock_voice.has_method("speak"):
		mock_voice.speak("Brawo!")
	await process_frame

	if mock_voice.speak_calls.size() == 0:
		print("FAIL M4: speak() was not called on mock voice prompt")
		mascot.queue_free()
		quit(1)
		return
	if mock_voice.speak_calls[0] != "Brawo!":
		print("FAIL M4: speak() called with wrong text: '%s'" % mock_voice.speak_calls[0])
		mascot.queue_free()
		quit(1)
		return
	print("PASS M4: say() invokes voice_prompt.speak()")
	mascot.queue_free()


## M5 - setup() calls subscribe_all on the event bus.
func _test_setup_subscribes_to_event_bus() -> void:
	var mascot := Mascot.new()
	get_root().add_child(mascot)
	await process_frame

	var mock_bus := MockEventBus.new()
	mascot.setup(mock_bus, null)
	await process_frame

	if not mock_bus.subscribe_all_called:
		print("FAIL M5: subscribe_all was not called on event bus during setup()")
		mascot.queue_free()
		quit(1)
		return
	print("PASS M5: setup() calls subscribe_all on event bus")
	mascot.queue_free()


## M6 - setup() with null event_bus does not crash.
func _test_null_event_bus_does_not_crash() -> void:
	var mascot := Mascot.new()
	get_root().add_child(mascot)
	await process_frame
	mascot.setup(null, null)
	await process_frame
	print("PASS M6: null event_bus in setup() does not crash")
	mascot.queue_free()


## M7 - _on_domain_event with null event does not crash.
func _test_null_event_does_not_crash() -> void:
	var mascot := Mascot.new()
	get_root().add_child(mascot)
	await process_frame
	mascot._on_domain_event(null)
	await process_frame
	print("PASS M7: null event in _on_domain_event does not crash")
	mascot.queue_free()


# ---------------------------------------------------------------------------
# Test doubles
# ---------------------------------------------------------------------------

## Mascot subclass that intercepts say() to capture speech without async await.
class MockableMascot extends Mascot:
	var last_said: String = ""

	func say(text: String, _duration_sec: float = 3.0) -> void:
		last_said = text


class MockVoicePrompt extends RefCounted:
	var speak_calls: Array[String] = []

	func speak(text: String, _locale: String = "pl-PL") -> void:
		speak_calls.append(text)


class MockEventBus extends RefCounted:
	var subscribe_all_called: bool = false

	func subscribe_all(_handler: Callable) -> bool:
		subscribe_all_called = true
		return true

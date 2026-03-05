class_name OnboardingService
extends RefCounted

## Service managing the first-time user experience (FTUE) flow.
## Tracks progress through "confidence loops" and persists completion state.

signal step_changed(step_id: String, instruction_key: String)
signal step_completed(step_id: String)
signal onboarding_finished

const STEP_WELCOME := "welcome"
const STEP_PLACE_FIRST := "place_first"
const STEP_PAINT_FIRST := "paint_first"
const STEP_PLAY := "test_play"

var _profile: PlayerProfile
var _current_step: String = ""

## Starts the onboarding flow if not already completed.
func start_onboarding(profile: PlayerProfile) -> void:
    _profile = profile
    if is_onboarding_complete():
        return
    
    _current_step = STEP_WELCOME
    step_changed.emit(_current_step, "onboarding.welcome")

## Returns true if the user has finished the tutorial previously.
func is_onboarding_complete() -> bool:
    if _profile == null:
        return false
    return _profile.preferences.get("onboarding_complete", false)

## Advances the flow if the action matches the current step requirements.
func record_action(action_type: String) -> void:
    if is_onboarding_complete():
        return
        
    match _current_step:
        STEP_WELCOME:
            # Welcome is dismissed by user acknowledgment, usually via advance_step directly
            pass
        STEP_PLACE_FIRST:
            if action_type == "place" or action_type == "add_node":
                _complete_current_step()
                _transition_to(STEP_PAINT_FIRST)
        STEP_PAINT_FIRST:
             if action_type == "paint":
                _complete_current_step()
                _transition_to(STEP_PLAY)
        STEP_PLAY:
            if action_type == "play" or action_type == "run_test":
                _complete_current_step()
                _finish_onboarding()

## Manually advance (e.g. from "Welcome" dialog OK button)
func acknowledge_welcome() -> void:
    if _current_step == STEP_WELCOME:
        _transition_to(STEP_PLACE_FIRST)

func _transition_to(next_step: String) -> void:
    _current_step = next_step
    var key := "onboarding.%s" % next_step
    step_changed.emit(_current_step, key)

func _complete_current_step() -> void:
    step_completed.emit(_current_step)

func _finish_onboarding() -> void:
    if _profile:
        _profile.preferences["onboarding_complete"] = true
    _current_step = ""
    onboarding_finished.emit()

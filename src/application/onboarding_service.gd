class_name OnboardingService
extends RefCounted

## Service managing the first-time user experience (FTUE) flow.
## Tracks progress through "confidence loops" and persists completion state.
## Signals have been removed (Phase 7c): all notifications go through event_bus.emit().

const STEP_WELCOME := "welcome"
const STEP_PLACE_FIRST := "place_first"
const STEP_PAINT_FIRST := "paint_first"
const STEP_PLAY := "test_play"

var _profile: PlayerProfile
var _current_step: String = ""
var _event_bus: DomainEventBus = null
var _warned_null_bus: bool = false


func setup(event_bus: DomainEventBus) -> OnboardingService:
	_event_bus = event_bus
	return self


## Starts the onboarding flow if not already completed.
func start_onboarding(profile: PlayerProfile) -> void:
	_profile = profile
	if is_onboarding_complete():
		return

	_current_step = STEP_WELCOME
	_emit(OnboardingStepChangedEvent.new(_current_step, "onboarding.welcome", _profile_id()))

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
	_emit(OnboardingStepChangedEvent.new(_current_step, key, _profile_id()))

func _complete_current_step() -> void:
	_emit(OnboardingStepCompletedEvent.new(_current_step, _profile_id()))

func _finish_onboarding() -> void:
	if _profile:
		_profile.preferences["onboarding_complete"] = true
	_current_step = ""
	_emit(OnboardingFinishedEvent.new(_profile_id()))

func _emit(event: DomainEvent) -> void:
	if _event_bus != null:
		_event_bus.emit(event)
	elif not _warned_null_bus:
		_warned_null_bus = true
		push_warning("OnboardingService: event_bus not wired; event lost: %s" % event.event_type)

func _profile_id() -> String:
	if _profile == null:
		return ""
	return _profile.profile_id

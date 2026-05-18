## Application service: moderates voice transcript before intent execution.
## Hex fix (Phase 3): STT is removed from this service. The adapter layer
## (ModeratingSttAdapter) handles raw audio and calls process() with a
## pre-transcribed string. This keeps the application layer framework-free.
## Pipeline: moderate(transcript) → if BLOCK return blocked result;
##            else extract_intent(transcript) → return success result.
class_name VoiceInputModerationService
extends RefCounted

var _moderation: ModerationPort
var _intent_extractor: IntentExtractorPort
var _event_bus: DomainEventBus
var _clock: ClockPort


## Setup the service. intent_extractor MUST be non-null — the service requires
## a typed port implementation for safe intent extraction. Passing null is an
## error: push_error is emitted and the call returns self so callers can detect
## the failure via _moderation being null.
func setup(
	moderation: ModerationPort,
	intent_extractor: IntentExtractorPort,
	event_bus: DomainEventBus = null,
	clock: ClockPort = null
) -> VoiceInputModerationService:
	if intent_extractor == null:
		push_error("VoiceInputModerationService.setup(): intent_extractor must not be null")
		return self
	_moderation = moderation
	_intent_extractor = intent_extractor
	_event_bus = event_bus
	_clock = clock
	return self


## Processes a pre-transcribed string through the safety pipeline.
## Returns a result dictionary with keys:
##   allowed: bool, transcript: String, intent: String,
##   moderation_verdict: String, reason: String,
##   category: String, safe_alternative: String
##
## Safety default: any error in moderation defaults to BLOCK.
func process(transcript: String, actor: PlayerProfile) -> Dictionary:
	if actor == null:
		return _failed_result("INVALID_ACTOR")
	if _moderation == null or _intent_extractor == null:
		return _failed_result("SERVICE_NOT_READY")
	if transcript.strip_edges().is_empty():
		return _failed_result("EMPTY_TRANSCRIPT")

	# Step 1: Moderate transcript BEFORE intent execution — safety default: BLOCK on error
	var moderation_result: ModerationResult
	moderation_result = _moderation.check_text(transcript, actor.age_band)

	if moderation_result == null or moderation_result.is_blocked():
		var safe_alt := _safe_alternative(moderation_result)
		_emit_safety_intervention(
			"VOICE_TRANSCRIPT_MODERATION_BLOCK",
			transcript,
			safe_alt,
			actor.profile_id
		)
		return {
			"allowed": false,
			"transcript": transcript,
			"intent": "",
			"moderation_verdict": "BLOCK",
			"reason": "VOICE_MODERATION_BLOCK",
			"category": moderation_result.category if moderation_result != null else "",
			"safe_alternative": safe_alt,
		}

	# Step 2: Extract intent from safe transcript
	var intent := _intent_extractor.extract_intent(transcript)

	return {
		"allowed": true,
		"transcript": transcript,
		"intent": intent,
		"moderation_verdict": "PASS" if not moderation_result.is_warning() else "WARN",
		"reason": "",
		"category": "",
		"safe_alternative": "",
	}


func _failed_result(reason: String) -> Dictionary:
	return {
		"allowed": false,
		"transcript": "",
		"intent": "",
		"moderation_verdict": "",
		"reason": reason,
		"category": "",
		"safe_alternative": "",
	}


func _safe_alternative(moderation_result: ModerationResult) -> String:
	if moderation_result == null:
		return "Spróbuj powiedzieć coś innego!"
	if not moderation_result.safe_alternative.strip_edges().is_empty():
		return moderation_result.safe_alternative
	return "Spróbuj powiedzieć coś innego!"


func _emit_safety_intervention(
	policy_rule: String,
	trigger_context: String,
	safe_alternative: String,
	actor_id: String
) -> void:
	if _event_bus == null:
		return

	var now := _clock.now_iso() if _clock != null else ""
	var now_msec := _clock.now_msec() if _clock != null else 0

	var decision_id := "voice_%d_%d" % [
		absi(trigger_context.hash()),
		now_msec,
	]

	var event := SafetyInterventionTriggeredEvent.new(decision_id, actor_id, now)
	event.decision_type = "BLOCK"
	event.policy_rule = policy_rule
	event.trigger_context = "[VOICE] %s" % trigger_context
	event.safe_alternative_offered = not safe_alternative.strip_edges().is_empty()
	_event_bus.emit(event)

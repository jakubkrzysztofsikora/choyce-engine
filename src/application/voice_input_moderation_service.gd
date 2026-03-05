## Application service: moderates voice input transcripts before intent execution.
## Orchestrates: transcribe → moderate → extract intent. Blocks unsafe
## transcripts with explainable safe alternatives and emits audit events.
class_name VoiceInputModerationService
extends RefCounted

var _stt: SpeechToTextPort
var _moderation: ModerationPort
var _intent_extractor: RefCounted  # expects extract_intent(String) -> String
var _event_bus: DomainEventBus
var _clock: ClockPort


func setup(
	stt: SpeechToTextPort,
	moderation: ModerationPort,
	intent_extractor: RefCounted = null,
	event_bus: DomainEventBus = null,
	clock: ClockPort = null
) -> VoiceInputModerationService:
	_stt = stt
	_moderation = moderation
	_intent_extractor = intent_extractor
	_event_bus = event_bus
	_clock = clock
	return self


## Processes voice audio through the full safety pipeline:
## transcribe → moderate → extract intent.
## Returns a result dictionary with keys:
##   allowed: bool, transcript: String, intent: String,
##   moderation_verdict: String, reason: String,
##   category: String, safe_alternative: String
func process_voice_input(
	audio: PackedByteArray,
	actor: PlayerProfile,
	language: String = "pl-PL"
) -> Dictionary:
	if actor == null:
		return _failed_result("INVALID_ACTOR")
	if _stt == null or _moderation == null:
		return _failed_result("SERVICE_NOT_READY")

	# Step 1: Transcribe via STT (local-first chain)
	var transcript := _stt.transcribe(audio, language)
	if transcript.strip_edges().is_empty():
		return _failed_result("TRANSCRIPTION_FAILED")

	# Step 2: Moderate transcript BEFORE intent execution
	var moderation_result := _moderation.check_text(transcript, actor.age_band)

	if moderation_result.is_blocked():
		var safe_alternative := _safe_alternative(moderation_result)
		_emit_safety_intervention(
			"VOICE_TRANSCRIPT_MODERATION_BLOCK",
			transcript,
			safe_alternative,
			actor.profile_id
		)
		return {
			"allowed": false,
			"transcript": transcript,
			"intent": "",
			"moderation_verdict": "BLOCK",
			"reason": "VOICE_MODERATION_BLOCK",
			"category": moderation_result.category,
			"safe_alternative": safe_alternative,
		}

	# Step 3: Extract intent from safe transcript
	var intent := ""
	if _intent_extractor != null and _intent_extractor.has_method("extract_intent"):
		intent = _intent_extractor.extract_intent(transcript)

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

## Outbound adapter: composes raw SpeechToTextPort + VoiceInputModerationService.
## All Godot signal / async plumbing stays here so the application layer never
## imports Godot Node or signal machinery. Phase 3 hex fix per Reviewer-3 critical #1.
##
## Transcription pipeline per call to transcribe():
##   1. Delegate to raw_stt.transcribe(audio, language) → raw transcript
##   2. Pass transcript through voice_mod.process(transcript, profile) → moderated result
##   3. Return the raw transcript string when allowed; return "" when blocked.
##
## The caller (inbound shell / voice assistant card) receives a plain String from the
## SpeechToTextPort contract. Blocked transcripts are silenced at this boundary —
## the shell observes an empty string and may display its own blocked-state UI based
## on the result dictionary stored in _last_result for inspection.
class_name ModeratingSttAdapter
extends SpeechToTextPort

var _raw_stt: SpeechToTextPort
var _voice_mod: VoiceInputModerationService

## Result of the last transcription + moderation pass. Consumers that need
## structured verdict information (e.g. to show a blocked toast) may read this.
var last_result: Dictionary = {}


func setup(
	raw_stt: SpeechToTextPort,
	voice_mod: VoiceInputModerationService
) -> ModeratingSttAdapter:
	_raw_stt = raw_stt
	_voice_mod = voice_mod
	return self


## Transcribes audio, then passes the transcript through the moderation service.
## The actor PlayerProfile is required for age-appropriate moderation rules.
## Returns the transcript string when safe, "" when blocked or on error.
func transcribe(audio: PackedByteArray, language: String = "") -> String:
	return transcribe_for_actor(audio, language, null)


## Full pipeline with explicit actor profile for moderation age-band selection.
## Inbound shells that have a profile should call this instead of transcribe().
func transcribe_for_actor(
	audio: PackedByteArray,
	language: String,
	actor: PlayerProfile
) -> String:
	last_result = {}

	if _raw_stt == null or _voice_mod == null:
		last_result = {
			"allowed": false,
			"transcript": "",
			"intent": "",
			"moderation_verdict": "",
			"reason": "ADAPTER_NOT_READY",
			"category": "",
			"safe_alternative": "",
		}
		return ""

	# Step 1: Raw transcription (may involve Godot signals in real adapter)
	var raw_transcript := _raw_stt.transcribe(audio, language)

	if raw_transcript.strip_edges().is_empty():
		last_result = {
			"allowed": false,
			"transcript": "",
			"intent": "",
			"moderation_verdict": "",
			"reason": "TRANSCRIPTION_FAILED",
			"category": "",
			"safe_alternative": "",
		}
		return ""

	# Step 2: Moderation + intent extraction — safety default: use a fallback profile
	# if none provided so moderation still runs (age_band defaults to CHILD_6_8)
	var effective_actor := actor
	if effective_actor == null:
		effective_actor = PlayerProfile.new("_anon", PlayerProfile.Role.KID)

	var result := _voice_mod.process(raw_transcript, effective_actor)
	last_result = result

	if not result.get("allowed", false):
		return ""

	return raw_transcript

## Outbound port for short spoken UI prompts (onboarding hints, caption narration).
## Distinct from TextToSpeechPort, which produces raw audio bytes for the audio
## governance pipeline; this port handles fire-and-forget UI speech without
## exposing buffers to callers.
class_name VoicePromptPort
extends RefCounted

## Playback lifecycle lets UI adapters keep captions and mouth movement in sync
## with actual generated/cached audio instead of a guessed text duration.
signal playback_started(text: String)
signal playback_finished(text: String)
## The adapter could not play the line (offline, failed request, or bounded
## queue). Consumers must show their readable fallback rather than wait forever.
signal playback_skipped(text: String)

func speak(_text: String, _locale: String = "pl-PL") -> void:
	pass


func is_available() -> bool:
	return false


func cancel() -> void:
	pass

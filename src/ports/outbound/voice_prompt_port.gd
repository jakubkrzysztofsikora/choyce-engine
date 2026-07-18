## Outbound port for short spoken UI prompts (onboarding hints, caption narration).
## Distinct from TextToSpeechPort, which produces raw audio bytes for the audio
## governance pipeline; this port handles fire-and-forget UI speech without
## exposing buffers to callers.
class_name VoicePromptPort
extends RefCounted

## Playback lifecycle lets UI adapters keep captions and mouth movement in sync
## with actual generated/cached audio instead of a guessed text duration.
## `request_id` lets a caller reject an old callback when two characters use
## the same short line. It is optional so one-shot UI prompts remain simple.
signal playback_started(text: String, request_id: int)
signal playback_finished(text: String, request_id: int)
## The adapter could not play the line (offline, failed request, or bounded
## queue). Consumers must show their readable fallback rather than wait forever.
signal playback_skipped(text: String, request_id: int)

func speak(_text: String, _locale: String = "pl-PL", _request_id: int = 0) -> void:
	pass


func is_available() -> bool:
	return false


func cancel() -> void:
	pass

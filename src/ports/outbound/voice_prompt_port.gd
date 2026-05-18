## Outbound port for short spoken UI prompts (onboarding hints, caption narration).
## Distinct from TextToSpeechPort, which produces raw audio bytes for the audio
## governance pipeline; this port handles fire-and-forget UI speech without
## exposing buffers to callers.
class_name VoicePromptPort
extends RefCounted


func speak(_text: String, _locale: String = "pl-PL") -> void:
	pass


func is_available() -> bool:
	return false


func cancel() -> void:
	pass

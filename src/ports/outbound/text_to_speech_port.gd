## Outbound port contract for text-to-speech playback.
## Hexagonal boundary: inbound UI adapters depend on this port, not on any concrete
## TTS provider. Implementations live in src/adapters/outbound/.
## Default implementation: silent / unavailable (safe fail-open for missing hardware).
class_name TextToSpeechPort
extends RefCounted


## Speak text aloud. Locale defaults to Polish (product default).
## Implementations MUST be fire-and-forget (no await required by callers).
func speak(text: String, locale: String = "pl-PL") -> void:
	pass


## Returns true when a TTS backend is ready to produce audio on the current device.
## UI adapters MUST call this before speak() to avoid silent failures.
func is_available() -> bool:
	return false


## Cancel any in-progress speech immediately.
func cancel() -> void:
	pass

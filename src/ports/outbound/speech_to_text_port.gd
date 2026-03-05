## Outbound port contract for speech transcription.
## Default language policy should be controlled in adapters.
class_name SpeechToTextPort
extends RefCounted


func transcribe(audio: PackedByteArray, language: String) -> String:
	push_error("SpeechToTextPort.transcribe() not implemented")
	return ""

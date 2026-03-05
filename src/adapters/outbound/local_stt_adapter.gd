## Local STT adapter using Whisper or similar local model.
## Defaults to Polish language and handles child pronunciation patterns.
class_name LocalSTTAdapter
extends SpeechToTextPort

var _language: String = "pl-PL"
var _model_path: String = "user://models/whisper-tiny-pl.gguf"  # Local Polish-tuned model

func setup(model_path: String = "user://models/whisper-tiny-pl.gguf") -> LocalSTTAdapter:
	_model_path = model_path
	return self

func transcribe(audio: PackedByteArray, language: String = "") -> String:
	# Use provided language or fall back to instance default (don't mutate state)
	var effective_language := language if language != "" else _language

	# TODO: Actual Whisper/Ollama integration for local STT
	# This is a placeholder implementation that simulates local STT

	if audio.size() == 0:
		return ""

	# Simulate transcription with Polish child speech tolerance
	# In a real implementation, this would call the local model
	var simulated_transcript: String

	# Simulate some common Polish child speech patterns
	if audio.size() < 100:
		simulated_transcript = "mama"
	elif audio.size() < 200:
		simulated_transcript = "tata"
	else:
		simulated_transcript = "chcę zbudować sklep"

	return simulated_transcript

func set_language(language: String) -> void:
	_language = language
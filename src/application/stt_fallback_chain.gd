## STT fallback chain: local first, cloud second with consent.
## Orchestrates the Polish-first STT pipeline. Maintains port contract:
## transcribe(audio, language) with profile and fallback settings injected via setup/set methods.
class_name STTFallbackChain
extends SpeechToTextPort

var _local_adapter: SpeechToTextPort
var _cloud_adapter: CloudSTTAdapter
var _profile_id: String = ""
var _allow_cloud_fallback: bool = true

func setup(local_adapter: SpeechToTextPort, cloud_adapter: CloudSTTAdapter) -> STTFallbackChain:
	_local_adapter = local_adapter
	_cloud_adapter = cloud_adapter
	return self

func set_profile(profile_id: String) -> void:
	_profile_id = profile_id
	if _cloud_adapter != null:
		_cloud_adapter.set_profile(profile_id)

func set_allow_cloud_fallback(allow: bool) -> void:
	_allow_cloud_fallback = allow

func transcribe(audio: PackedByteArray, language: String) -> String:
	# Always try local first
	var local_result := _local_adapter.transcribe(audio, language)

	# If local succeeds or cloud fallback not allowed, return local result
	if local_result != "" or not _allow_cloud_fallback:
		return local_result

	# Try cloud fallback if local failed (CloudSTTAdapter will check consent internally)
	if _cloud_adapter != null:
		return _cloud_adapter.transcribe(audio, language)

	return local_result  # Return empty string if no cloud adapter

func set_language(language: String) -> void:
	if _local_adapter != null:
		_local_adapter.set_language(language)
	if _cloud_adapter != null:
		_cloud_adapter.set_language(language)
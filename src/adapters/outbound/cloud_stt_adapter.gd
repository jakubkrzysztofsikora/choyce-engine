## Cloud STT adapter (ElevenLabs or similar) with consent gating.
## Requires parent opt-in and preserves Polish intent extraction.
class_name CloudSTTAdapter
extends SpeechToTextPort

var _consent_port: IdentityConsentPort
var _language: String = "pl-PL"
var _api_key: String = ""  # Would be loaded from secure storage
var _profile_id: String = ""

func setup(consent_port: IdentityConsentPort, api_key: String = "") -> CloudSTTAdapter:
	_consent_port = consent_port
	_api_key = api_key
	return self

func set_profile(profile_id: String) -> void:
	_profile_id = profile_id

func transcribe(audio: PackedByteArray, language: String = "") -> String:
	if language != "":
		_language = language

	# FAIL-CLOSED: Block cloud STT if no profile or no consent
	if _profile_id == "" or not _consent_port.has_consent(_profile_id, "cloud_stt"):
		return ""

	if audio.size() == 0:
		return ""

	# TODO: Actual ElevenLabs API integration
	# This is a placeholder that simulates cloud STT

	var simulated_transcript: String
	if audio.size() < 100:
		simulated_transcript = "mama"
	elif audio.size() < 200:
		simulated_transcript = "tata"
	else:
		simulated_transcript = "chcę zbudować duży sklep"

	return simulated_transcript

func set_language(language: String) -> void:
	_language = language
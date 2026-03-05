class_name CloudSTTAdapterTest
extends ApplicationTest


class MockConsentPort:
	extends IdentityConsentPort

	var _consents: Dictionary = {}

	func grant_consent(profile_id: String, consent_key: String) -> void:
		if profile_id not in _consents:
			_consents[profile_id] = {}
		_consents[profile_id][consent_key] = true

	func has_consent(profile_id: String, consent_key: String) -> bool:
		return _consents.get(profile_id, {}).get(consent_key, false)

	func revoke_consent(profile_id: String, consent_key: String) -> void:
		if profile_id in _consents:
			_consents[profile_id].erase(consent_key)


var _adapter: CloudSTTAdapter
var _consent_port: MockConsentPort

func _init():
	_consent_port = MockConsentPort.new()
	_adapter = CloudSTTAdapter.new().setup(_consent_port)

func _reset():
	_checks_run = 0
	_failures = []

func run() -> Dictionary:
	test_empty_audio()
	test_empty_profile_blocks_transcription()
	test_consent_required_for_cloud()
	test_consent_granted_allows_transcription()
	return _build_result("CloudSTTAdapter")

func test_empty_audio():
	_reset()
	_adapter.set_profile("child-1")
	_consent_port.grant_consent("child-1", "cloud_stt")
	var result := _adapter.transcribe(PackedByteArray())
	_assert_eq(result, "", "Empty audio should return empty string")

func test_empty_profile_blocks_transcription():
	_reset()
	# No profile set - should FAIL CLOSED even with consent available
	_consent_port.grant_consent("", "cloud_stt")
	var test_audio := PackedByteArray([1, 2, 3, 4, 5])
	var result := _adapter.transcribe(test_audio)
	_assert_eq(result, "", "Empty profile_id should block transcription (FAIL CLOSED)")

func test_consent_required_for_cloud():
	_reset()
	_adapter.set_profile("child-1")
	# Don't grant consent
	var test_audio := PackedByteArray([1, 2, 3, 4, 5])
	var result := _adapter.transcribe(test_audio)
	_assert_eq(result, "", "Cloud STT should require explicit consent")

func test_consent_granted_allows_transcription():
	_reset()
	_adapter.set_profile("child-1")
	_consent_port.grant_consent("child-1", "cloud_stt")
	var test_audio := PackedByteArray([1, 2, 3, 4, 5])
	var result := _adapter.transcribe(test_audio)
	_assert_ne(result, "", "Consent granted should allow transcription")
	_assert_true(result.to_utf8_buffer().size() > 0, "Result should be UTF-8 encodable")

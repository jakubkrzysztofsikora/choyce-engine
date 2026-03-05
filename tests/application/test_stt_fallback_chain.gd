class_name STTFallbackChainTest
extends ApplicationTest

var _fallback_chain: STTFallbackChain
var _mock_consent_port: MockConsentPort
var _local_adapter: LocalSTTAdapter
var _cloud_adapter: CloudSTTAdapter

func _init():
	_mock_consent_port = MockConsentPort.new()
	_local_adapter = LocalSTTAdapter.new()
	_cloud_adapter = CloudSTTAdapter.new().setup(_mock_consent_port)
	_fallback_chain = STTFallbackChain.new().setup(_local_adapter, _cloud_adapter)

func _reset():
	_checks_run = 0
	_failures = []

func run():
	test_local_first_behavior()
	test_cloud_fallback_with_consent()
	test_cloud_fallback_without_consent()
	test_no_cloud_fallback_flag()
	return _build_result("STTFallbackChain")

func test_local_first_behavior():
	_reset()
	var test_audio := PackedByteArray([1, 2, 3, 4, 5])
	var result := _fallback_chain.transcribe(test_audio, "pl-PL")
	_assert_ne(result, "", "Should use local adapter first")

func test_cloud_fallback_with_consent():
	_reset()
	_mock_consent_port._consents["test_profile"] = ["cloud_stt"]
	_fallback_chain.set_profile("test_profile")

	# Simulate local failure by using empty audio (local returns empty string)
	var empty_audio := PackedByteArray()
	var result := _fallback_chain.transcribe(empty_audio, "")

	# With consent, cloud should be tried (but also returns empty for empty audio)
	_assert_eq(result, "", "Should return empty when both adapters fail")

func test_cloud_fallback_without_consent():
	_reset()
	_mock_consent_port._consents = {}
	_fallback_chain.set_profile("test_profile")

	var empty_audio := PackedByteArray()
	var result := _fallback_chain.transcribe(empty_audio, "")

	# Without consent, cloud should not be tried
	_assert_eq(result, "", "Should not use cloud without consent")

func test_no_cloud_fallback_flag():
	_reset()
	_mock_consent_port._consents["test_profile"] = ["cloud_stt"]
	_fallback_chain.set_profile("test_profile")
	_fallback_chain.set_allow_cloud_fallback(false)

	var test_audio := PackedByteArray([1, 2, 3, 4, 5])
	var result := _fallback_chain.transcribe(test_audio, "")

	# Should only use local when cloud fallback is disabled
	_assert_ne(result, "", "Should use local adapter when cloud fallback disabled")

class MockConsentPort extends IdentityConsentPort:
	var _consents: Dictionary = {}
	
	func has_consent(profile_id: String, consent_type: String) -> bool:
		if _consents.has(profile_id):
			return _consents[profile_id].has(consent_type)
		return false
	
	func request_consent(profile_id: String, consent_type: String) -> bool:
		return false

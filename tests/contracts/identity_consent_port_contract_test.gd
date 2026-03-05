class_name IdentityConsentPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := IdentityConsentPort.new()

	_assert_has_method(port, "has_consent")
	_assert_has_method(port, "request_consent")

	var has_consent := port.has_consent("profile-1", "cloud_sync")
	_assert_false(
		has_consent,
		"IdentityConsentPort.has_consent(profile_id, consent_type)"
	)

	var has_consent_empty := port.has_consent("", "")
	_assert_false(
		has_consent_empty,
		"IdentityConsentPort.has_consent(empty_profile_id, empty_consent_type)"
	)

	var request := port.request_consent("profile-1", "cloud_sync")
	_assert_false(
		request,
		"IdentityConsentPort.request_consent(profile_id, consent_type)"
	)

	var request_empty := port.request_consent("", "")
	_assert_false(
		request_empty,
		"IdentityConsentPort.request_consent(empty_profile_id, empty_consent_type)"
	)

	return _build_result("IdentityConsentPort")

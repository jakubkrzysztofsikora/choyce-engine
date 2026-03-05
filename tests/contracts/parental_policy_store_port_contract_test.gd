class_name ParentalPolicyStorePortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := ParentalPolicyStorePort.new()

	_assert_has_method(port, "save_policy")
	_assert_has_method(port, "load_policy")

	# Default save returns false
	var policy := ParentalControlPolicy.new()
	var saved := port.save_policy("parent-1", policy)
	_assert_true(not saved, "Default save_policy should return false")

	# Default load returns null
	var loaded := port.load_policy("parent-1")
	_assert_null(loaded, "Default load_policy")

	return _build_result("ParentalPolicyStorePort")

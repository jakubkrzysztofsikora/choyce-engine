class_name ClockPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := ClockPort.new()

	_assert_has_method(port, "now_iso")
	_assert_has_method(port, "now_msec")

	var iso := port.now_iso()
	_assert_string(iso, "ClockPort.now_iso()")

	var msec := port.now_msec()
	_assert_int(msec, "ClockPort.now_msec()")

	return _build_result("ClockPort")

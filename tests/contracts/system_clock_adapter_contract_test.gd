class_name SystemClockAdapterContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var clock := SystemClock.new()

	_assert_has_method(clock, "now_iso")
	_assert_has_method(clock, "now_msec")

	var iso_now := clock.now_iso()
	_assert_string(iso_now, "SystemClock.now_iso()")
	_assert_true(not iso_now.is_empty(), "SystemClock.now_iso() should not be empty")
	_assert_true(
		iso_now.contains("T"),
		"SystemClock.now_iso() should return ISO-8601-like format"
	)

	var now_msec := clock.now_msec()
	_assert_int(now_msec, "SystemClock.now_msec()")
	_assert_true(now_msec > 0, "SystemClock.now_msec() should be positive")

	return _build_result("SystemClockAdapter")

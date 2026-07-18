class_name TailnetVoiceAdapterContractTest
extends PortContractTest

const TAILNET_VOICE_ADAPTER := preload("res://src/adapters/outbound/tailnet_voice_adapter.gd")


func run() -> Dictionary:
	_reset()

	var adapter := TAILNET_VOICE_ADAPTER.new()
	_assert_has_method(adapter, "setup")
	_assert_has_method(adapter, "is_available")
	_assert_has_method(adapter, "speak")
	_assert_has_method(adapter, "cancel")
	_assert_has_method(adapter, "set_active_voice_id")

	_assert_true(adapter.is_available(), "TailnetVoiceAdapter should report available")

	return _build_result("TailnetVoiceAdapter")

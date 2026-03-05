class_name AssetRepositoryPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := AssetRepositoryPort.new()

	_assert_has_method(port, "store")
	_assert_has_method(port, "load")
	_assert_has_method(port, "exists")

	var stored := port.store("asset-1", PackedByteArray())
	_assert_bool(stored, "AssetRepositoryPort.store(asset_id, data)")

	var stored_empty := port.store("", PackedByteArray())
	_assert_bool(stored_empty, "AssetRepositoryPort.store(empty_id, empty_data)")

	var loaded := port.load("asset-1")
	_assert_packed_byte_array(loaded, "AssetRepositoryPort.load(asset_id)")

	var loaded_empty := port.load("")
	_assert_packed_byte_array(loaded_empty, "AssetRepositoryPort.load(empty_id)")

	var exists_result := port.exists("asset-1")
	_assert_bool(exists_result, "AssetRepositoryPort.exists(asset_id)")

	var exists_empty := port.exists("")
	_assert_bool(exists_empty, "AssetRepositoryPort.exists(empty_id)")

	return _build_result("AssetRepositoryPort")

## Outbound port contract for binary asset storage and retrieval.
## Keeps domain and use-cases agnostic to filesystem/cloud implementations.
class_name AssetRepositoryPort
extends RefCounted


func store(asset_id: String, data: PackedByteArray) -> bool:
	push_error("AssetRepositoryPort.store() not implemented")
	return false


func load(asset_id: String) -> PackedByteArray:
	push_error("AssetRepositoryPort.load() not implemented")
	return PackedByteArray()


func exists(asset_id: String) -> bool:
	push_error("AssetRepositoryPort.exists() not implemented")
	return false

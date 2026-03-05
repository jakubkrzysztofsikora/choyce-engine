## Outbound port for curated marketplace and family catalog persistence APIs.
class_name MarketplaceCatalogPort
extends RefCounted


func list_entries(filters: Dictionary = {}, limit: int = 50) -> Array:
	push_error("MarketplaceCatalogPort.list_entries() not implemented")
	return []


func save_entry(entry: Dictionary) -> bool:
	push_error("MarketplaceCatalogPort.save_entry() not implemented")
	return false


func load_entry(entry_id: String) -> Dictionary:
	push_error("MarketplaceCatalogPort.load_entry() not implemented")
	return {}

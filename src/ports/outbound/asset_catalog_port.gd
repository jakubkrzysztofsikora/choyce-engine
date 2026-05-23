## Outbound port: gives the BUILDER palette + AI creation flows a
## hex-clean read-only view over the in-tree CC0 asset bundles.
##
## Pure RefCounted abstract base. The concrete
## KenneyAssetCatalogAdapter scans the `data/models/.../` subtrees and
## a hand-curated `kid_safe_allowlist.txt` to produce entries.
##
## Per Adv-1 hex-arch review: ports never see Godot types. Adapters do
## the I/O; application services only call these methods.
class_name AssetCatalogPort
extends RefCounted


## All kid-safe entries for the given category. Empty string returns
## the union across visible BUILDER categories. Returns [] when nothing
## matches (never null — keeps caller branching simple).
func list_kid_safe(_category: String = "") -> Array:
	_unimplemented("list_kid_safe")
	return []


## Lookup by catalog_id. Returns null when unknown.
func get_by_id(_catalog_id: String) -> AssetCatalogEntry:
	_unimplemented("get_by_id")
	return null


## How many catalog entries the port has indexed in total. Useful for
## telemetry + sanity tests.
func size() -> int:
	_unimplemented("size")
	return 0


func _unimplemented(method_name: String) -> void:
	push_error("AssetCatalogPort.%s called on abstract base — wire a concrete adapter" % method_name)

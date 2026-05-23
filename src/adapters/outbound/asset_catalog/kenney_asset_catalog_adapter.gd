## Concrete AssetCatalogPort adapter. Walks the bundled CC0 subtrees
## under `data/models/{kaykit,quaternius,kenney}/` and intersects them
## with the hand-curated `data/models/kenney/kid_safe_allowlist.txt`
## file so only explicitly allowed props end up in the BUILDER palette.
##
## Adapter, not application: this is the I/O side. Scans use Godot
## DirAccess + FileAccess. The resulting `Array[AssetCatalogEntry]` is
## a pure domain list the application layer can hand around.
##
## Allowlist line format (one per line, # comments, blank lines OK):
##   <repo-relative-path> [| <category>] [| <display_name_pl>]
##
## If the optional fields are omitted, category is inferred from the
## path segment (kaykit/builder/objects -> BUILDINGS, etc.) and the
## display name falls back to the file basename uppercased.
class_name KenneyAssetCatalogAdapter
extends AssetCatalogPort

## Path is relative to res:// so it survives PCK packaging.
const _ALLOWLIST_PATH := "res://data/models/kenney/kid_safe_allowlist.txt"

var _entries: Array = []
var _index_by_id: Dictionary = {}
var _initialized: bool = false


func _init() -> void:
	# Defer scan to first call so test fixtures can stub before use.
	pass


## Force a (re)scan. Tests can call this after dropping a fake allowlist
## under res://data/models/kenney/. Idempotent.
func reload() -> int:
	_entries.clear()
	_index_by_id.clear()
	_initialized = true
	_load_allowlist()
	return _entries.size()


func list_kid_safe(category: String = "") -> Array:
	if not _initialized:
		reload()
	if category == "":
		var out: Array = []
		for e in _entries:
			if (e as AssetCatalogEntry).is_visible_in_builder():
				out.append(e)
		return out
	var filtered: Array = []
	for e in _entries:
		var entry: AssetCatalogEntry = e
		if entry.category == category and entry.is_visible_in_builder():
			filtered.append(entry)
	return filtered


func get_by_id(catalog_id: String) -> AssetCatalogEntry:
	if not _initialized:
		reload()
	return _index_by_id.get(catalog_id, null)


func size() -> int:
	if not _initialized:
		reload()
	return _entries.size()


# ---- internals ----

func _load_allowlist() -> void:
	if not FileAccess.file_exists(_ALLOWLIST_PATH):
		push_warning("KenneyAssetCatalogAdapter: allowlist missing at %s — empty catalog" % _ALLOWLIST_PATH)
		return
	var file := FileAccess.open(_ALLOWLIST_PATH, FileAccess.READ)
	if file == null:
		push_error("KenneyAssetCatalogAdapter: cannot open %s" % _ALLOWLIST_PATH)
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var entry := _parse_line(line)
		if entry != null:
			_entries.append(entry)
			_index_by_id[entry.catalog_id] = entry
	file.close()


func _parse_line(line: String) -> AssetCatalogEntry:
	var parts := Array(line.split("|", false))
	for i in range(parts.size()):
		parts[i] = String(parts[i]).strip_edges()
	if parts.size() < 1 or parts[0] == "":
		return null
	var mesh_path: String = parts[0]
	var category: String = parts[1] if parts.size() >= 2 and parts[1] != "" else _infer_category(mesh_path)
	var display_name: String = parts[2] if parts.size() >= 3 and parts[2] != "" else _default_display_name(mesh_path)
	var catalog_id: String = _derive_catalog_id(mesh_path)
	return AssetCatalogEntry.new(catalog_id, mesh_path, category, 1, 1.0, display_name)


func _derive_catalog_id(path: String) -> String:
	# data/models/kaykit/builder/objects/wall.gltf.glb -> kaykit_builder_objects/wall
	var trimmed := path
	if trimmed.begins_with("data/models/"):
		trimmed = trimmed.substr("data/models/".length())
	var base := trimmed.get_file().get_basename()
	# strip the ".gltf" middle from KayKit's `.gltf.glb` files
	if base.ends_with(".gltf"):
		base = base.substr(0, base.length() - ".gltf".length())
	var dir := trimmed.get_base_dir().replace("/", "_")
	return "%s/%s" % [dir, base]


func _default_display_name(path: String) -> String:
	var base := path.get_file().get_basename()
	if base.ends_with(".gltf"):
		base = base.substr(0, base.length() - ".gltf".length())
	return base.replace("_", " ").to_upper()


## Category inference from the path. Conservative: anything unknown
## drops to DECORATION so the palette still shows it, just in the
## catch-all tab.
func _infer_category(path: String) -> String:
	var p := path.to_lower()
	# KayKit builder
	if p.find("kaykit/builder/tiles_") != -1:
		return AssetCatalogEntry.CAT_BLOCKS
	if p.find("kaykit/builder/objects") != -1:
		return AssetCatalogEntry.CAT_BUILDINGS
	# KayKit adventurers
	if p.find("kaykit/adventurers/characters") != -1:
		return AssetCatalogEntry.CAT_CHARACTERS
	if p.find("kaykit/adventurers/assets") != -1:
		# Weapons / arrows / shields — keep out of BUILDER palette.
		return AssetCatalogEntry.CAT_ADVENTURERS_GEAR
	# Quaternius nature
	if p.find("quaternius/nature") != -1:
		return AssetCatalogEntry.CAT_TREES_PLANTS
	# Existing individual GLBs at the top level
	if p.find("quaternius/") != -1:
		return AssetCatalogEntry.CAT_CHARACTERS
	if p.find("kaykit/") != -1:
		return AssetCatalogEntry.CAT_DECORATION
	return AssetCatalogEntry.CAT_DECORATION

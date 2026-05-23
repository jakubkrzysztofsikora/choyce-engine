## Domain value object: one kid-safe item that can appear in the
## BUILDER palette. Loaded by KenneyAssetCatalogAdapter from a hand
## curated allowlist file (data/models/kenney/kid_safe_allowlist.txt)
## plus the bundled KayKit / Quaternius subtrees committed in-tree.
##
## Pure data, RefCounted, no Godot types.
##
## Category strings map to the 8 kid-readable palette tabs in MVP plan
## §8: TREES_PLANTS, FOOD, BUILDINGS, BLOCKS, ANIMALS, VEHICLES,
## DECORATION, CHARACTERS, plus an internal ADVENTURERS_GEAR bucket the
## BUILDER palette filters out (weapons stay out of the build flow).
class_name AssetCatalogEntry
extends RefCounted

const CAT_TREES_PLANTS := "TREES_PLANTS"
const CAT_FOOD := "FOOD"
const CAT_BUILDINGS := "BUILDINGS"
const CAT_BLOCKS := "BLOCKS"
const CAT_ANIMALS := "ANIMALS"
const CAT_VEHICLES := "VEHICLES"
const CAT_DECORATION := "DECORATION"
const CAT_CHARACTERS := "CHARACTERS"
const CAT_ADVENTURERS_GEAR := "ADVENTURERS_GEAR"  ## not exposed in BUILDER

const BUILDER_VISIBLE_CATEGORIES := [
	CAT_TREES_PLANTS,
	CAT_FOOD,
	CAT_BUILDINGS,
	CAT_BLOCKS,
	CAT_ANIMALS,
	CAT_VEHICLES,
	CAT_DECORATION,
	CAT_CHARACTERS,
]

## Stable id used by PlaceObjectFromCatalogService + WorldEditCommand.
## Convention: `<source>/<basename>` (e.g. `kaykit_builder/wall_doorway`).
var catalog_id: String
## Repo-relative path to the .glb / .fbx file.
var mesh_path: String
## One of the CAT_* constants.
var category: String
## 0 = unrated, 1 = safe (default), 2 = parent-only.
var kid_safe_rating: int
var default_scale: float
## Polish display name for the palette tile. Empty == fall back to file
## basename uppercased.
var display_name_pl: String


func _init(
	p_catalog_id: String = "",
	p_mesh_path: String = "",
	p_category: String = CAT_DECORATION,
	p_kid_safe_rating: int = 1,
	p_default_scale: float = 1.0,
	p_display_name_pl: String = "",
) -> void:
	catalog_id = p_catalog_id
	mesh_path = p_mesh_path
	category = p_category
	kid_safe_rating = p_kid_safe_rating
	default_scale = p_default_scale
	display_name_pl = p_display_name_pl


func is_visible_in_builder() -> bool:
	return category in BUILDER_VISIBLE_CATEGORIES and kid_safe_rating >= 1

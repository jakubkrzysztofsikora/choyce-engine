## Bounded, cosmetic-only player-character customization. Face selects a
## Kenney character-male-{a..f} GLB variant. Each color slot is an int
## index into a fixed palette so the choices stay bounded and cannot be
## used to drive gameplay stats. Persisted as plain JSON under user://
## so choices survive a local replay without touching the project store
## or any parental-control pipeline.
class_name CharacterCustomization
extends RefCounted

static var PERSIST_PATH := "user://character_customization.json"
const FACE_VARIANTS := ["a", "b", "c", "d", "e", "f"]
const SKIN_PALETTE := [
	Color(0.99, 0.84, 0.69),  ## light
	Color(0.93, 0.74, 0.55),  ## medium-light
	Color(0.78, 0.58, 0.40),  ## medium
	Color(0.55, 0.40, 0.28),  ## dark
]
const HAIR_PALETTE := [
	Color(0.20, 0.13, 0.08),  ## dark brown
	Color(0.55, 0.35, 0.16),  ## chestnut
	Color(0.93, 0.78, 0.42),  ## blonde
	Color(0.78, 0.30, 0.18),  ## auburn
]
const TOP_PALETTE := [
	Color(0.85, 0.30, 0.25),  ## red
	Color(0.30, 0.55, 0.85),  ## blue
	Color(0.40, 0.70, 0.40),  ## green
	Color(0.92, 0.78, 0.30),  ## yellow
]
const PANTS_PALETTE := [
	Color(0.40, 0.30, 0.20),  ## brown
	Color(0.22, 0.25, 0.38),  ## navy
	Color(0.55, 0.55, 0.55),  ## grey
	Color(0.15, 0.40, 0.30),  ## forest
]
const SHOES_PALETTE := [
	Color(0.30, 0.20, 0.12),  ## dark leather
	Color(0.85, 0.85, 0.85),  ## white
	Color(0.10, 0.10, 0.10),  ## black
	Color(0.62, 0.40, 0.22),  ## tan
]

var face: String = "a"
var skin: int = 0
var hair: int = 0
var top: int = 0
var pants: int = 0
var shoes: int = 0


func clamp_in_place() -> CharacterCustomization:
	face = FACE_VARIANTS[clamp(FACE_VARIANTS.find(face), 0, FACE_VARIANTS.size() - 1)] if face in FACE_VARIANTS else "a"
	skin = clamp(skin, 0, SKIN_PALETTE.size() - 1)
	hair = clamp(hair, 0, HAIR_PALETTE.size() - 1)
	top = clamp(top, 0, TOP_PALETTE.size() - 1)
	pants = clamp(pants, 0, PANTS_PALETTE.size() - 1)
	shoes = clamp(shoes, 0, SHOES_PALETTE.size() - 1)
	return self


func to_dict() -> Dictionary:
	return {
		"face": face,
		"skin": skin,
		"hair": hair,
		"top": top,
		"pants": pants,
		"shoes": shoes,
	}


static func from_dict(d: Dictionary) -> CharacterCustomization:
	var c := CharacterCustomization.new()
	c.face = String(d.get("face", "a"))
	c.skin = int(d.get("skin", 0))
	c.hair = int(d.get("hair", 0))
	c.top = int(d.get("top", 0))
	c.pants = int(d.get("pants", 0))
	c.shoes = int(d.get("shoes", 0))
	return c.clamp_in_place()


static func load_from_disk() -> CharacterCustomization:
	if not FileAccess.file_exists(PERSIST_PATH):
		return CharacterCustomization.new().clamp_in_place()
	var file := FileAccess.open(PERSIST_PATH, FileAccess.READ)
	if file == null:
		return CharacterCustomization.new().clamp_in_place()
	var raw := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return CharacterCustomization.new().clamp_in_place()
	return from_dict(parsed as Dictionary)


func save_to_disk() -> bool:
	var file := FileAccess.open(PERSIST_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(), "  "))
	file.close()
	return true
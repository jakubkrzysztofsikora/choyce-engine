## Domain-only CharacterCustomization contract.
## Run: godot --headless --path . --script tests/domain/test_character_customization.gd
extends SceneTree

const CUSTOMIZATION := preload("res://src/domain/gameplay/character_customization.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_defaults()
	_test_round_trip()
	_test_legacy_save_preserves_swatches()
	_test_clamp()
	if _failures.is_empty():
		print("[test_character_customization] OK")
		quit(0)
	else:
		printerr("[test_character_customization] FAIL ", _failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _test_defaults() -> void:
	var c := CUSTOMIZATION.new()
	_expect(c.face == "a" and c.hero_identity == "ziemek" and c.use_signature_outfit,
		"new profile starts as the Ziemek signature preset")


func _test_round_trip() -> void:
	var src := CUSTOMIZATION.new()
	src.face = "d"
	src.skin = 2
	src.hair = 3
	src.top = 1
	src.pants = 2
	src.shoes = 3
	src.hero_identity = "gniewko"
	src.use_signature_outfit = false
	var loaded := CUSTOMIZATION.from_dict(src.to_dict())
	_expect(loaded.face == "d" and loaded.skin == 2 and loaded.hair == 3 and loaded.top == 1 and loaded.pants == 2 and loaded.shoes == 3,
		"all bounded cosmetic selections round-trip")
	_expect(loaded.hero_identity == "gniewko" and not loaded.use_signature_outfit,
		"identity and explicit wardrobe override round-trip")


func _test_legacy_save_preserves_swatches() -> void:
	var legacy := CUSTOMIZATION.from_dict({"face": "b", "top": 2, "pants": 1, "shoes": 3})
	_expect(legacy.hero_identity == "ziemek" and not legacy.use_signature_outfit,
		"legacy saved swatches are not overwritten by the new first-run preset")


func _test_clamp() -> void:
	var c := CUSTOMIZATION.new()
	c.face = "invalid"
	c.skin = -1
	c.hair = 99
	c.top = 99
	c.pants = -2
	c.shoes = 99
	c.hero_identity = "invalid"
	c.clamp_in_place()
	_expect(c.face == "a" and c.skin == 0 and c.hair == CUSTOMIZATION.HAIR_PALETTE.size() - 1,
		"face, skin and hair clamp to bounded choices")
	_expect(c.top == CUSTOMIZATION.TOP_PALETTE.size() - 1 and c.pants == 0 and c.shoes == CUSTOMIZATION.SHOES_PALETTE.size() - 1,
		"garment choices clamp to bounded palettes")
	_expect(c.hero_identity == "ziemek", "unknown hero identity falls back safely")

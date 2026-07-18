## Unit tests for CharacterCustomization persistence + clamp behavior.
## Run: godot --headless --script tests/domain/test_character_customization.gd
##
## Uses ad-hoc test paths under user://test_char_customization_*.json so the
## test never disturbs the real player save. PERSIST_PATH on the data class
## is mutated per test to keep using the existing load_from_disk / save_to_disk
## code paths.
class_name TestCharacterCustomization
extends SceneTree

const _CUSTOMIZATION := preload("res://src/domain/gameplay/character_customization.gd")


func _init() -> void:
	var failures: Array = []

	_test_defaults_when_no_file(failures)
	_test_round_trip(failures)
	_test_clamp_out_of_range(failures)
	_test_unknown_face_falls_back(failures)
	_test_corrupt_json_falls_back(failures)
	_test_save_writes_json(failures)
	_test_palette_bounds_match_indices(failures)

	if failures.is_empty():
		print("[test_character_customization] OK")
		quit(0)
	else:
		printerr("[test_character_customization] FAIL ", failures.size())
		for f in failures:
			printerr("  - ", f)
		quit(1)


func _isolated_path(suffix: String) -> String:
	return "user://test_char_customization_%s.json" % suffix


func _wipe(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _with_path(path: String, fn: Callable) -> void:
	var prev := _CUSTOMIZATION.PERSIST_PATH
	_CUSTOMIZATION.PERSIST_PATH = path
	fn.call()
	_CUSTOMIZATION.PERSIST_PATH = prev


func _test_defaults_when_no_file(failures: Array) -> void:
	var path := _isolated_path("defaults")
	_with_path(path, func() -> void:
		_wipe(path)
		var c := _CUSTOMIZATION.load_from_disk()
		if c.face != "a":
			failures.append("defaults_face: got=%s" % c.face)
		if c.skin != 0 or c.hair != 0 or c.top != 0 or c.pants != 0 or c.shoes != 0:
			failures.append("defaults_indices: skin=%d hair=%d top=%d pants=%d shoes=%d" %
				[c.skin, c.hair, c.top, c.pants, c.shoes])
	)


func _test_round_trip(failures: Array) -> void:
	var path := _isolated_path("roundtrip")
	_with_path(path, func() -> void:
		_wipe(path)
		var src := _CUSTOMIZATION.new()
		src.face = "d"
		src.skin = 2
		src.hair = 3
		src.top = 1
		src.pants = 2
		src.shoes = 3
		var saved: bool = src.save_to_disk()
		if not saved:
			failures.append("round_trip_save: save returned false")
			return
		var loaded := _CUSTOMIZATION.load_from_disk()
		if loaded.face != "d":
			failures.append("round_trip_face: got=%s" % loaded.face)
		if loaded.skin != 2:
			failures.append("round_trip_skin: got=%d" % loaded.skin)
		if loaded.hair != 3:
			failures.append("round_trip_hair: got=%d" % loaded.hair)
		if loaded.top != 1:
			failures.append("round_trip_top: got=%d" % loaded.top)
		if loaded.pants != 2:
			failures.append("round_trip_pants: got=%d" % loaded.pants)
		if loaded.shoes != 3:
			failures.append("round_trip_shoes: got=%d" % loaded.shoes)
	)


func _test_clamp_out_of_range(failures: Array) -> void:
	var c := _CUSTOMIZATION.new()
	c.face = "z"
	c.skin = -1
	c.hair = 99
	c.top = 5
	c.pants = -2
	c.shoes = 10
	c.clamp_in_place()
	if c.face != "a":
		failures.append("clamp_face_unknown: got=%s" % c.face)
	if c.skin != 0:
		failures.append("clamp_skin_negative: got=%d" % c.skin)
	if c.hair != _CUSTOMIZATION.HAIR_PALETTE.size() - 1:
		failures.append("clamp_hair_overflow: got=%d" % c.hair)
	if c.top != _CUSTOMIZATION.TOP_PALETTE.size() - 1:
		failures.append("clamp_top_overflow: got=%d" % c.top)
	if c.pants != 0:
		failures.append("clamp_pants_negative: got=%d" % c.pants)
	if c.shoes != _CUSTOMIZATION.SHOES_PALETTE.size() - 1:
		failures.append("clamp_shoes_overflow: got=%d" % c.shoes)


func _test_unknown_face_falls_back(failures: Array) -> void:
	var path := _isolated_path("unknown_face")
	_with_path(path, func() -> void:
		_wipe(path)
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string('{"face":"zzz","skin":1,"hair":1,"top":1,"pants":1,"shoes":1}')
		f.close()
		var c := _CUSTOMIZATION.load_from_disk()
		if c.face != "a":
			failures.append("unknown_face_fallback: got=%s" % c.face)
		if c.skin != 1:
			failures.append("unknown_face_other_fields_lost: skin=%d" % c.skin)
	)


func _test_corrupt_json_falls_back(failures: Array) -> void:
	var path := _isolated_path("corrupt")
	_with_path(path, func() -> void:
		_wipe(path)
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string("{this is not valid json")
		f.close()
		var c := _CUSTOMIZATION.load_from_disk()
		if c.face != "a":
			failures.append("corrupt_json_face: got=%s" % c.face)
		if c.skin != 0 or c.hair != 0:
			failures.append("corrupt_json_other_fields: skin=%d hair=%d" % [c.skin, c.hair])
	)


func _test_save_writes_json(failures: Array) -> void:
	var path := _isolated_path("save_writes_json")
	_with_path(path, func() -> void:
		_wipe(path)
		var c := _CUSTOMIZATION.new()
		c.face = "c"
		c.skin = 1
		c.hair = 2
		c.top = 3
		c.pants = 0
		c.shoes = 2
		var ok: bool = c.save_to_disk()
		if not ok:
			failures.append("save_writes_json_ok: false")
			return
		var f := FileAccess.open(path, FileAccess.READ)
		var raw := f.get_as_text()
		f.close()
		if not raw.contains('"face": "c"'):
			failures.append("save_writes_json_face_in_file: raw=%s" % raw)
		if not raw.contains('"top": 3'):
			failures.append("save_writes_json_top_in_file: raw=%s" % raw)
	)


func _test_palette_bounds_match_indices(failures: Array) -> void:
	## Face variants and color palettes must stay aligned with the panel
	## (6 face buttons + 4 swatches per color row).
	var c := _CUSTOMIZATION.new()
	if c.FACE_VARIANTS.size() != 6:
		failures.append("face_variants_size: got=%d" % c.FACE_VARIANTS.size())
	for name in ["SKIN_PALETTE", "HAIR_PALETTE", "TOP_PALETTE", "PANTS_PALETTE", "SHOES_PALETTE"]:
		var palette: Array = c.get(name)
		if palette.size() != 4:
			failures.append("%s_size: got=%d" % [name, palette.size()])
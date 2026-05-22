extends SceneTree
# Verify Polish diacritics render in Rajdhani (body font).
# Also verifies Audiowide + Rubik Glitch load and resolve glyphs for
# the basic Latin set.

const FONT_DIR := "res://data/fonts/voxel/"
const POLISH_DIACRITICS := ["ą", "ć", "ę", "ł", "ń", "ó", "ś", "ź", "ż"]


func _init() -> void:
	var failures: Array[String] = []

	var rajdhani := _load_font(FONT_DIR + "rajdhani_regular.ttf", failures)
	var rajdhani_bold := _load_font(FONT_DIR + "rajdhani_bold.ttf", failures)
	var rajdhani_semi := _load_font(FONT_DIR + "rajdhani_semibold.ttf", failures)
	var audiowide := _load_font(FONT_DIR + "audiowide.ttf", failures)
	var rubik := _load_font(FONT_DIR + "rubik_glitch.ttf", failures)

	# Polish diacritics MUST render in every Rajdhani weight (body font).
	for variant in [["rajdhani_regular", rajdhani], ["rajdhani_bold", rajdhani_bold], ["rajdhani_semibold", rajdhani_semi]]:
		var name: String = String(variant[0])
		var font: FontFile = variant[1]
		if font == null:
			continue
		for ch in POLISH_DIACRITICS:
			var cp: int = ch.unicode_at(0)
			if not _has_glyph(font, cp):
				failures.append("%s missing glyph for U+%04X (%s)" % [name, cp, ch])

	# Audiowide + Rubik Glitch are display/header — only verify basic Latin.
	for variant in [["audiowide", audiowide], ["rubik_glitch", rubik]]:
		var name: String = String(variant[0])
		var font: FontFile = variant[1]
		if font == null:
			continue
		for ch in ["A", "Z", "0", "9"]:
			var cp: int = ch.unicode_at(0)
			if not _has_glyph(font, cp):
				failures.append("%s missing glyph for U+%04X (%s)" % [name, cp, ch])

	if failures.is_empty():
		print("[voxel_font_diacritics] PASS — all 9 Polish diacritics + Latin basics resolved.")
		quit(0)
	else:
		for line in failures:
			push_error("[voxel_font_diacritics] " + line)
			print("FAIL: " + line)
		quit(1)


func _load_font(path: String, failures: Array[String]) -> FontFile:
	if not ResourceLoader.exists(path):
		failures.append("font missing on disk: " + path)
		return null
	var res := ResourceLoader.load(path)
	if res == null or not (res is FontFile):
		failures.append("font failed to load as FontFile: " + path)
		return null
	return res


func _has_glyph(font: FontFile, codepoint: int) -> bool:
	# Font.has_char returns true when the codepoint is mapped to a glyph.
	return font.has_char(codepoint)

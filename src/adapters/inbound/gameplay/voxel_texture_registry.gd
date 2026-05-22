class_name VoxelTextureRegistry
extends RefCounted

# Voxel phonk-aesthetic texture registry.
#
# Maps Polish material keys to StandardMaterial3D instances backed by CC0
# texture packs that ship in data/textures/voxel/. Used by combat-mode
# world rendering and by the create shell when the kid picks a phonk skin.
#
# Hex-arch placement: this is an inbound-adapter helper. It owns the path
# constants for art assets so the application layer never references
# res:// paths directly. It is intentionally a RefCounted (not a Node /
# Autoload) so the lifecycle is the same as other adapters.
#
# CC0 sources (see LICENSE.txt beside each pack):
#   - ambientCG (Metal032/034, Concrete019/033, Asphalt022, PaintedMetal002)
#   - Poly Haven Shanghai Bund HDRI (loaded by world_renderer.gd separately)
#   - texture.ninja-style glitch / CRT / scanline overlays (procedural CC0)

const _AMBIENTCG_ROOT := "res://data/textures/voxel/ambientcg"
const _GLITCH_ROOT := "res://data/textures/voxel/glitch_overlays"

# Polish material keys → ambientCG pack directory + file stem.
# Stem matches the slimmed-down file layout under each pack folder.
const _MATERIAL_DEFS: Dictionary = {
	"metal_porysowany": {       # scratched metal
		"pack": "Metal032",
		"stem": "Metal032_1K-PNG",
		"metalness": true,
	},
	"metal_neon": {             # painted neon metal
		"pack": "PaintedMetal002",
		"stem": "PaintedMetal002_1K-PNG",
		"metalness": true,
	},
	"metal_zardzewialy": {      # rust-finish metal
		"pack": "Metal034",
		"stem": "Metal034_1K-PNG",
		"metalness": true,
	},
	"mur_betonowy": {           # plain concrete wall
		"pack": "Concrete019",
		"stem": "Concrete019_1K-PNG",
		"metalness": false,
	},
	"beton_brutalist": {        # rough brutalist concrete
		"pack": "Concrete033",
		"stem": "Concrete033_1K-PNG",
		"metalness": false,
	},
	"asfalt_graffiti": {        # asphalt road / graffiti base
		"pack": "Asphalt022",
		"stem": "Asphalt022_1K-PNG",
		"metalness": false,
	},
}

# Polish overlay keys → glitch_overlays PNG file stem.
const _OVERLAY_DEFS: Dictionary = {
	"linie_skanowania":        "scanlines_fine",
	"linie_skanowania_grube":  "scanlines_thick",
	"crt_winieta":             "crt_vignette",
	"glitch_rgb":              "glitch_rgb_shift",
	"szum_statyczny":          "static_noise",
	"siatka_neonowa":          "neon_grid",
	"vhs_rozdarcie":           "vhs_tearing",
}

var _material_cache: Dictionary = {}    # key -> StandardMaterial3D
var _overlay_cache: Dictionary = {}     # key -> Texture2D


# Returns a StandardMaterial3D for the given Polish key, or null if the key
# is unknown or the underlying texture files are missing on disk. Callers
# should accept null gracefully (fallback to flat color) — this keeps
# the registry safe to use in headless tests where image-import may not
# have run.
func get_material(key: String) -> StandardMaterial3D:
	if _material_cache.has(key):
		return _material_cache[key]
	if not _MATERIAL_DEFS.has(key):
		return null
	var def: Dictionary = _MATERIAL_DEFS[key]
	var base_path := "%s/%s/%s" % [_AMBIENTCG_ROOT, def["pack"], def["stem"]]
	var color_tex := _load_texture("%s_Color.png" % base_path)
	if color_tex == null:
		return null  # underlying art missing — caller falls back
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = color_tex
	var normal_tex := _load_texture("%s_NormalGL.png" % base_path)
	if normal_tex != null:
		mat.normal_enabled = true
		mat.normal_texture = normal_tex
	var rough_tex := _load_texture("%s_Roughness.png" % base_path)
	if rough_tex != null:
		mat.roughness_texture = rough_tex
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	if def.get("metalness", false):
		var metal_tex := _load_texture("%s_Metalness.png" % base_path)
		if metal_tex != null:
			mat.metallic_texture = metal_tex
			mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
			mat.metallic = 1.0
	mat.resource_name = "voxel_%s" % key
	_material_cache[key] = mat
	return mat


# Returns a glitch / scanline / CRT overlay Texture2D for the given Polish
# key, or null if the key is unknown or the file is missing.
func get_overlay(key: String) -> Texture2D:
	if _overlay_cache.has(key):
		return _overlay_cache[key]
	if not _OVERLAY_DEFS.has(key):
		return null
	var stem: String = _OVERLAY_DEFS[key]
	var tex := _load_texture("%s/%s.png" % [_GLITCH_ROOT, stem])
	if tex == null:
		return null
	_overlay_cache[key] = tex
	return tex


# Returns the list of registered material keys (Polish). Useful for parent-
# zone configuration UI and for the test harness assert.
func list_material_keys() -> PackedStringArray:
	var out := PackedStringArray()
	for k in _MATERIAL_DEFS.keys():
		out.append(k)
	return out


# Returns the list of registered overlay keys (Polish).
func list_overlay_keys() -> PackedStringArray:
	var out := PackedStringArray()
	for k in _OVERLAY_DEFS.keys():
		out.append(k)
	return out


# Lightweight existence + load helper. Returns null on any failure so the
# caller can degrade gracefully (this is the "kid-safe defaults" principle
# applied to art: missing pack must never crash combat mode).
func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var res := ResourceLoader.load(path)
	if res is Texture2D:
		return res
	return null

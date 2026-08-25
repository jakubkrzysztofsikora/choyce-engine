class_name StyleGuide
extends Resource
## Project-wide look. ONE of these, referenced by every
## StylizedMaterialComponent. Change it here, the whole game changes.
##
## This is the mechanism that lets you mix Kenney + KayKit + Quaternius and
## still ship something that reads as one game.

@export_group("Surface")
@export var roughness: float = 0.75
@export var metallic: float = 0.0
@export var specular: float = 0.35

@export_group("Rim light")
@export var rim_enabled: bool = true
@export_range(0.0, 1.0) var rim_strength: float = 0.45
@export_range(0.0, 1.0) var rim_tint: float = 0.6

@export_group("Outline")
@export var outline_enabled: bool = true
@export var outline_width: float = 0.02
@export var outline_colour: Color = Color(0.08, 0.07, 0.12)

@export_group("Palette")
## Reference palette. Assets get retinted toward these to force cohesion.
@export var palette: Array[Color] = [
	Color("#ff8a5c"), Color("#5cc8ff"), Color("#b6ff5c"),
	Color("#ffd95c"), Color("#e05cff"), Color("#7fb35e"),
]

@export_group("Wind")
## Written to global shader uniforms every frame by the level; every foliage,
## cloth and flag shader reads the SAME values so the world sways in sync.
@export var wind_direction: Vector3 = Vector3(1, 0, 0.3)
@export var wind_strength: float = 0.35
@export var wind_speed: float = 1.2


static func fallback() -> StyleGuide:
	return StyleGuide.new()


func nearest_palette(c: Color) -> Color:
	var best := c
	var best_d := INF
	for p in palette:
		var d := Vector3(p.r - c.r, p.g - c.g, p.b - c.b).length_squared()
		if d < best_d:
			best_d = d
			best = p
	return best

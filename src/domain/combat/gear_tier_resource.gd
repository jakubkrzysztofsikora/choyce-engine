## A single tier on the gear ladder. Authored as .tres in
## res://data/gear/. Replaces the inline `_weapon_tiers` Array literal
## in gameplay_runtime.gd (Adv 1 H1 hex-arch fix).
##
## Parent can tune tier_id labels + costs in Godot inspector — design
## tool baked into the engine. unlock_level lets us gate Epicki miecz
## behind XP level 3 (engagement curve fix per Adv 4).
class_name GearTierResource
extends Resource

@export var tier_id: String = ""
@export var display_name: String = ""
@export var weapon_damage: int = 4
## XP level required to even attempt crafting this tier. 0 = no
## level gate. Combined with the recipe cost, this prevents kids
## from rushing past their skill floor with lucky early drops.
@export var unlock_level: int = 0
## Crafting recipe: item_id -> count.
@export var recipe: Dictionary = {}

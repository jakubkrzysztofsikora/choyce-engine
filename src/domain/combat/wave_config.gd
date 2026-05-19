## Single wave's spawn recipe. Authored as .tres in res://data/waves/.
## WaveDirectorService consumes the array sorted by wave_number.
## Difficulty curve numbers chosen for 7yo per procedural-research:
##   count = 3 + N * 1.2 (truncated)
##   hp_mult = 1 + sqrt(N) * 0.25 (flat early, slow ramp)
##   speed_mult = clamp(1 + N * 0.04, 1.0, 1.4)
##   boss every 5th wave
##
## Per ParentalControlPolicy.combat_wave_cap, the director may halt
## at a parent-chosen cap regardless of how many WaveConfigs are
## authored (Adv 2 H-3 difficulty-cliff fix).
class_name WaveConfig
extends Resource

@export var wave_number: int = 1
@export var pack_size: int = 3
@export var hp_mult: float = 1.0
@export var speed_mult: float = 1.0
@export var is_boss_wave: bool = false
## Map of enemy_id -> weight. WaveDirector samples weighted-random.
## Empty dict falls back to all archetypes equal weight.
@export var archetype_weights: Dictionary = {}

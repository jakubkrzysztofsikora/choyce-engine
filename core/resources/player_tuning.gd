class_name PlayerTuning
extends Resource
## Every number a designer needs to feel out the character, in one Resource.
##
## These used to be `const`s inside the player script. Movement speed is the
## most-iterated number in any game and it must not require a code edit and a
## git conflict to change.

@export_group("Movement")
@export var speed: float = 7.0
@export var acceleration: float = 16.0
@export var jump_velocity: float = 6.5

@export_group("Camera")
@export var cam_distance: float = 7.0
@export var cam_height: float = 3.0
@export var cam_look_at_height: float = 1.2
## Smoothing half-life in seconds. Framerate-INDEPENDENT: a raw
## lerp(a, b, k * delta) makes camera feel differ between the 118 fps
## single-player case and the 63 fps four-player case, which players notice and
## cannot articulate.
@export var cam_smoothing_halflife: float = 0.06
@export var look_speed_stick: float = 3.0
@export var look_speed_mouse: float = 0.003
@export var pitch_min_degrees: float = -60.0
@export var pitch_max_degrees: float = 45.0
## Distance kept from any surface the camera would otherwise clip into.
@export var cam_collision_margin: float = 0.35

@export_group("Combat")
@export var melee_range: float = 2.6
@export var melee_damage: float = 12.0
@export var max_health: float = 100.0

@export_group("Interaction")
@export var reach: float = 4.0
@export var hold_distance: float = 1.6
@export var hold_height: float = 0.4

@export_group("Survival")
@export var kill_plane_y: float = -30.0
@export var respawn_delay: float = 1.5
@export var respawn_invulnerable_seconds: float = 2.0

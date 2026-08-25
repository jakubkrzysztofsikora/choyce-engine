class_name Layers
extends RefCounted
## Single source of truth for 3D physics layers.
## Names mirror ProjectSettings layer_names/3d_physics/layer_N.
## NEVER hardcode a bitmask anywhere else in the project.

const WORLD_STATIC      := 1 << 0   # layer 1
const TERRAIN           := 1 << 1   # layer 2
const BUILD_PLACED      := 1 << 2   # layer 3
const BUILD_GHOST       := 1 << 3   # layer 4  (query-only, collides with nothing)
const PLAYER_BODY       := 1 << 4   # layer 5
const PLAYER_HURTBOX    := 1 << 5   # layer 6
const NPC_BODY          := 1 << 6   # layer 7
const NPC_HURTBOX       := 1 << 7   # layer 8
const PROP_DYNAMIC      := 1 << 8   # layer 9
const DEBRIS            := 1 << 9   # layer 10 (never collides with DEBRIS)
const VEHICLE           := 1 << 10  # layer 11
const PROJECTILE        := 1 << 11  # layer 12
const INTERACT_TRIGGER  := 1 << 12  # layer 13
const GRAB_TARGET       := 1 << 13  # layer 14
const CAMERA_OCCLUDER   := 1 << 14  # layer 15

## Common composite masks.
const SOLID_WORLD  := WORLD_STATIC | TERRAIN | BUILD_PLACED
const ALL_BODIES   := SOLID_WORLD | PLAYER_BODY | NPC_BODY | PROP_DYNAMIC | VEHICLE
const HURTBOXES    := PLAYER_HURTBOX | NPC_HURTBOX
## Debris deliberately collides with the static world ONLY.
## Debris-vs-debris is the quadratic contact explosion that kills framerate.
const DEBRIS_MASK  := SOLID_WORLD
## What a build ghost tests against when validating placement.
const BUILD_BLOCKERS := SOLID_WORLD | PLAYER_BODY | NPC_BODY | VEHICLE | PROP_DYNAMIC

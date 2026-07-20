# Plan: Fix gym, water, textures, input using proven patterns

## Root causes (from deep research)

### Gym equipment has no collision
The gym GLB is instantiated with 57 MeshInstance3D children but none have collision shapes. Godot 4 provides `MeshInstance3D.create_trimesh_collision()` for this — auto-generates StaticBody3D + ConcavePolygonShape3D from mesh geometry. The gym spawner never calls them.

### E key "just moves camera"
E is mapped to both `interact` AND `exit_vehicle`. The training check runs in `_process()` via `Input.is_action_just_pressed()` polling. But the camera also reads input in `_input()`. Neither calls `set_input_as_handled()`, so the event cascades.

### Water disappears when entering bridge
The water ribbon Y is hardcoded at 0.20m. When the player walks onto the bridge (which raises terrain to 0.69m), the water mesh stays at Y=0.20 — it's physically below the bridge deck. The camera on the bridge looks down and sees the bridge deck, not the water (which is 49cm below).

### Textures float over ground (7 bugs)
1. Water ribbon: hardcoded Y=0.20, doesn't follow terrain
2. Bridge deck: visual top at Y=0.85 but walk collision at Y=0.69 → 16cm gap
3. BuildGrid: cell_to_world returns fixed Y, no terrain awareness
4. Homestead spawner: anchors all use Y=0.0, never calls _terrain_grounded_position()
5. Decorative props: _add_visual_asset defaults ground_to_terrain=false
6. Starter home walls: direct position assignment, no grounding
7. Gym spawner default arg: footgun if called without pre-grounding

## Implementation plan (4 phases)

### Phase 1: Gym collision + input fix
**Files**: gym_spawner_3d.gd, player_controller.gd

1. After gym GLB instantiation, walk every MeshInstance3D child and call `mi.create_trimesh_collision()` — auto-generates StaticBody3D + ConcavePolygonShape3D for all 57 equipment pieces
2. Move interact from _process polling to _unhandled_input(event):
   ```gdscript
   func _unhandled_input(event: InputEvent) -> void:
       if event.is_action_pressed("interact"):
           if _try_interact_training():
               get_viewport().set_input_as_handled()
           return
   ```
3. Remove the E-key block from _process_nutrition_training_input
4. Add brief exercise feedback: player scale tween 1.0→1.1→1.0 over 0.5s + 8 sparkle particles at station

### Phase 2: Full river with BoxMesh segments + buoyancy
**Files**: world_renderer.gd (replace _add_water_crossing), player_controller.gd

1. Replace the custom-shader meandering ribbon with BoxMesh segments (each ~20m × 8m × 0.3m) placed along the existing river path coordinates
2. Each segment Y = _terrain_grounded_position(center).y + 0.05 (follows terrain, no more hardcoded 0.20m)
3. StandardMaterial3D with transparency = ALPHA, albedo_color = Color(0.15, 0.45, 0.60, 0.75) — no custom shader
4. create_trimesh_collision() on each water segment for real surface
5. Buoyancy in player_controller.gd: when _in_water, gravity × 0.4, Space = swim up (velocity.y = 3.0)

Risks:
- BoxMesh segments have seams between them. Visible discontinuity at joints.
- Trimesh collision on water means the player STANDS on the riverbed, not swims. The Area3D buoyancy check needs to coexist with the trimesh.
- Multiple BoxMesh segments = multiple draw calls (vs 1 for the ribbon). Performance impact at 20+ segments.
- Replacing the entire river system means the _create_meandering_river_mesh function and its shoreline ribbon are deleted. Any code that references the old water node by name will break.

### Phase 3: Fix all 7 floating-mesh bugs
**Files**: world_renderer.gd, homestead_spawner_3d.gd, build_grid.gd, settlement_placement_service.gd

1. Homestead anchors → _terrain_grounded_position()
2. BuildGrid place_block → accept terrain height callback, snap Y to terrain
3. Bridge deck visual top → 0.69 (match walk surface)
4. Decorative props → ground_to_terrain = true default
5. Starter home walls → ground through _terrain_grounded_position()

Risks:
- Changing ground_to_terrain default to true changes ALL existing prop placements. Props that were intentionally floating (birds, clouds) would snap to ground.
- BuildGrid terrain callback changes the setup() signature. All callers must be updated.
- Bridge deck Y change from 0.85 to 0.69 requires adjusting the ramp endpoints too, or the ramps won't meet the deck.

### Phase 4: Block textures improvement
**Files**: build_grid.gd

1. Increase noise texture to 128×128 for finer detail
2. Add generated normal map from the same noise for 3D surface relief
3. Set mat.normal_texture alongside mat.albedo_texture

Risks:
- Normal map generation from noise requires Image manipulation per pixel. Could be slow on first placement.
- 128×128 = 16384 pixels per block kind × 8 kinds = 131072 Image.create + set_pixel calls on first load. May cause a frame hitch.

## Open questions for reviewer
1. Should the water BoxMesh segments replace the Area3D water volume entirely, or coexist? The Area3D handles body_entered for splash/buoyancy flags. The BoxMesh handles collision. If both exist, the player triggers Area3D AND stands on the trimesh simultaneously.
2. The create_trimesh_collision() on 57 gym meshes will generate 57 StaticBody3D children. Performance impact? Should we use create_convex_collision() instead for simpler shapes?
3. The _terrain_grounded_position() function reads from Terrain3D data. If Terrain3D hasn't loaded yet when props are placed, the function returns Y=0. Should we defer prop placement until terrain is ready?

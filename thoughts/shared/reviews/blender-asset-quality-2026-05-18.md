---
date: 2026-05-18
reviewer: blender-assets
commit: 68d73a3
status: complete
---
# Review: Blender Asset Quality

## Summary
Asset pipeline is fundamentally broken. The seven shipped glTF props plus the bunny mascot all share an identical, copy-pasted `baseColorFactor = [0.8, 0.8, 0.8, 1]` despite having semantic material names like `PropGold`, `PropCrystal`, `MascotPink`, `MascotPeach` — every prop renders the same grey unless `WorldRenderer._apply_toon_to_prop` masks it. The shell scene `world_renderer.gd` references **23 missing glTF props** (`apple.gltf`, `boat.gltf`, `barn.gltf`, …) plus the wrong filename `fence_segment.gltf` (file on disk is `fence.gltf`), so 24 of 31 mapped Polish keys silently fall back to grey primitives. The `bunny.gltf` mascot is fully authored but **not wired anywhere** — `mascot.gd` still uses `_draw()` 2D circles, and the entire Kenney survival_kit + toon_characters libraries (≈4.7 MB GLB + ≈14 MB unused FBX/OBJ) are dead weight in the repo.

## Findings (severity-ranked)

### Critical (block release)

- **23 missing prop glTF files break `WorldRenderer` for every non-trivial world.**
  `src/adapters/inbound/gameplay/world_renderer.gd:37-74` maps 31 Polish display-names to prop paths, but only 7 files exist (`chest`, `coin`, `fence`, `grass_tuft`, `palm`, `rock`, `spawn_crystal`). Missing: `apple.gltf`, `apple_tree.gltf`, `barn.gltf`, `boat.gltf`, `chicken.gltf`, `egg.gltf`, `fence_segment.gltf` (mismatch: real file is `fence.gltf`), `firefly_jar.gltf`, `flag_pole.gltf`, `flower_patch.gltf`, `glowing_acorn.gltf`, `hay_bale.gltf`, `hollow_log.gltf`, `mossy_rock.gltf`, `mushroom_large.gltf`, `mushroom_small.gltf`, `oak_tree.gltf`, `pearl.gltf`, `rock_pile.gltf`, `rope_bridge.gltf`, `starfish.gltf`, `water_trough.gltf`, `windmill.gltf`. Three whole worlds (farm `stodoła/jabłoń/wiatrak`, forest `dąb/grzyb/kłoda`, beach `łódka/flaga/rozgwiazda`) have zero authored props. The fallback at `_create_prop_node:144-147` is `push_warning` + primitive box — so the seed worlds render as featureless grey boxes.

- **Filename mismatch: `fence_segment.gltf` lookup vs. `fence.gltf` on disk.**
  `world_renderer.gd:53` (`"płot": "res://data/models/props/fence_segment.gltf"`) — the only fence asset on disk is `data/models/props/fence.gltf`. The fence prop is unreachable from any world spec.

- **Every glTF material has identical placeholder `baseColorFactor [0.8, 0.8, 0.8, 1]`.**
  All 21 materials across the 7 props (`PropWood`, `PropGold`, `PropWoodDark`, `PropCrystal`, `PropLeaf`, `PropTrunk`, `PropGrass`, `PropMoss`, `PropStone`) and all 5 bunny materials (`MascotPeach`, `MascotWhite`, `MascotPink`, `MascotDark`, `MascotNose`) carry the same grey factor. Authored intent is encoded only in the material *name* — meaning the gold coin, the pink bunny cheeks, the green grass blades, and the brown wood trim are all visually identical out of Blender. `WorldRenderer._apply_toon_to_prop` salvages this by reading `StandardMaterial3D.albedo_color`, but if Godot doesn't synthesise a per-material colour from the name, every prop ships as monochrome grey. There are **no PBR textures, no vertex colours, no per-material differentiation** in any shipped glTF. For a kid-targeted game, this is a release blocker — the visual fidelity advertised by the material taxonomy is fake.

- **`bunny.gltf` mascot is authored but never instantiated.**
  `data/models/mascot/bunny.gltf` (22 KB glTF + 170 KB bin, 18 meshes, 5 materials, parented under root `Mascot` node) is a fully built rigless bunny. But `src/adapters/inbound/shared/ui/mascot.gd:1-3` is still a `Control` calling `_draw()` with `draw_circle` primitives. The comment at line 3 ("Wave V3 note: replace _draw() with AnimatedSprite2D/glTF when Blender assets land") is now stale — the glTF has landed and was never wired. No `bunny.gltf` reference exists anywhere in `src/` or `tests/`.

### High

- **All shipped glTFs have `doubleSided: true` on every material** (21/21 prop materials, 5/5 mascot materials). Double-sided rendering is acceptable for grass blades, palm leaves, and cheap foliage; it is wasteful for the chest (cube primitives with 24 verts each), coin (closed cylinder), rock (closed icosphere), fence posts/rails (closed cubes/cylinders), bunny body/head/ears/feet (closed spheres). Roughly half these surfaces should be single-sided. Cost: 2x fragment shading per pixel on already-solid geometry. For a kid mobile/web target this is the difference between 60 fps and 30 fps on integrated GPUs.

- **Default mesh names are Blender auto-names, not exported asset names.**
  Every glTF has meshes named `Cube`, `Cube.001`, `Cube.005`, `Cone`, `Cone.005`, `Sphere`, `Sphere.001` … `Sphere.017`, `Cylinder`, `Cylinder.002`, `Cylinder.003`, `Icosphere`. Node names are correct (`ChestLid`, `PalmTrunk`, `EarL_Inner`), but the underlying *mesh data-block* names betray that the authoring file (`props_master.blend`) was exported without rename-on-export. This will bite any future Godot scene replacing meshes by name (`get_node("Cube.005")` is unreviewable). The mascot's 18 spheres are particularly bad — `Sphere.016` is the left arm; `Sphere.013` is foot-right-back. Untraceable.

- **`props_v2.blend` and `bunny.blend` missing — `props_master.blend` (100 KB) is the only source file.**
  Coordinator's review list calls for `props_v2.blend` and `bunny.blend`. Only `data/models/props/props_master.blend` and `data/models/mascot/bunny.blend` (138 KB) exist. There's no `props_v2.blend` in the repo root or the props dir. Either the review brief is stale or someone forgot to commit. Either way, re-deriving the missing 23 props requires the source file — and there's no toolchain doc explaining how `props_master.blend` was sliced into per-prop glTFs.

- **`bunny.gltf` scale anchor is wrong for a UI mascot drop-in.**
  Body verts span Y ∈ [-0.55, +0.55] (Belly mesh, accessor 7) but the `Body` node is translated to Y = 0.55 and the `EarL` is at Y = 2.25 with scale Y = 2.6 — so the rendered bunny extends from Y ≈ 0 to Y ≈ 4.0 (ears stretch from Y ≈ 2.25 to Y ≈ 4.05). When dropped into `mascot.tscn`, this needs aggressive downscale or repositioning. No `Y_UP → Y_UP` 4-meter character belongs in a Control-sized mascot.

### Medium

- **Crystal bottom rotation is a quaternion close-to-singular `[-1, 0, 0, 4.37e-08]`.**
  `data/models/props/spawn_crystal.gltf:CrystalBottom` rotation: that fourth component is essentially zero (`4.371138828673793e-08`), meaning a 180° rotation around X. Godot will deal with it, but exporting `(-1, 0, 0, ~0)` is a Blender-side bug — the export should have normalized to `(0, 0, 0, 0)` if no rotation was intended, or `(1, 0, 0, 0)` if the artist did flip the cone. This kind of near-zero-w quaternion was a known glTF-Blender-IO regression around v5.x. Verify the spawn crystal renders right-side-up in-engine.

- **Coin geometry uses 98 verts for a tiny collectible, but chest uses only 24-vert primitives.**
  Mesh `Cylinder.001` (the coin) has 98 positions/normals/UVs and 276 indices — that's a 16-sided cylinder with separate caps. The coin is 7 cm scale; that detail is wasted at distance. Meanwhile the chest is 5 unsubdivided cube primitives (24 verts each = 120 total). Inconsistent LOD strategy. Consider 8-sided coin (40 verts) and bevelled chest (≈200 verts).

- **Palm has 7 leaf meshes each with **89 verts and 360 indices**, totalling 623 verts of leaf data per tree** — and they're all instance-duplicates that should be sharing one `Sphere.001` mesh. The exporter unrolled them into seven separate `Sphere.001`–`Sphere.006` data-blocks (same vert count, same indices accessor #7, same min/max bounds) — but each leaf still gets its own POSITION/NORMAL/TEXCOORD bufferView (1068 + 1068 + 712 = 2848 bytes × 7 = ≈20 KB redundant). One shared accessor with seven instancing nodes would cut palm size from 24 KB to ≈5 KB.

- **Spawn crystal uses two cones sharing material `PropCrystal` but no transparency / emission.**
  The "spawn point" surface is described as glowing in `_create_spawn_point_node` (added programmatically: `OmniLight3D`, `GPUParticles3D`). The crystal mesh itself has roughness 0.5, no emission, no transparency — it's a solid grey cone. Visually disconnected from the cyan glow the renderer wraps around it.

- **No UV unwrap quality check possible — UVs exist (TEXCOORD_0 in every primitive) but no texture is referenced, so they are purely decorative.** With no `baseColorTexture` / `normalTexture` / `metallicRoughnessTexture` defined anywhere, the UV data is wasted bandwidth (≈ 192 bytes/mesh × dozens of meshes). If textures will never land, strip TEXCOORD_0 from export.

- **`data/textures/landing/cloud_*.png` are 2048×2048 PNG at 2–2.5 MB each.**
  Three cloud sprites totalling 7 MB of PNG for a landing-screen background. `cloud_02.png` and `cloud_03.png` are grayscale+alpha — should be far smaller. Re-encode to WebP or strip to alpha-only PNG8 (~50–150 KB each). Combined landing texture payload (`sky_main` 3072×1536 + 3 clouds + sun + grass) is ≈ 7.6 MB just to render a static title screen.

- **Kenney `survival_kit` and `toon_characters` libraries ship FBX + OBJ + GLB triplicates totalling ~18 MB on disk, and not one model is referenced from Godot.**
  - `data/models/kenney/survival_kit/Models/FBX format/` = 2.5 MB
  - `data/models/kenney/survival_kit/Models/OBJ format/` = 1.5 MB
  - `data/models/kenney/survival_kit/Models/GLB format/` = 1.4 MB (only GLB is used by Godot 4)
  - `data/models/kenney/toon_characters/Models/FBX format/` = 8.8 MB
  - `data/models/kenney/toon_characters/Models/OBJ format/` = 1.2 MB
  - `data/models/kenney/toon_characters/Models/GLB format/` = 3.3 MB
  - Plus 320 KB + 104 KB of `Previews/`, 116 KB + 108 KB `Preview.png`, 96 KB `Sample.png`, two `.url` shortcut files per library.
  `rg "models/kenney" src/ tests/` returns zero hits — no scene, script, or test references any of it. Drop FBX + OBJ + Previews and you save ~14 MB of repo weight for zero functional loss.

- **Kenney `toon_characters` includes accessibility props (`aid-cane-blind`, `aid-cane-low-vision`, `aid-hearing`, `aid-mask`, `aid-glasses`, `aid-crutch`, `aid-defibrillator-{green,red}`, `wheelchair-power-deluxe`) — none referenced.** Possibly intentional future-feature scaffolding, but if these aren't on a near-term roadmap, they're shipping in every build of the engine. Confirm with product before keeping.

- **Particle textures ship twice: `PNG (Black background)/` 4.2 MB + `PNG (Transparent)/` 5.3 MB.**
  Kenney bundles both variants. Only transparent particles are useful in a game runtime. The black-background set is for marketing/preview only. 4.2 MB to delete.

### Low / nits

- **Mesh node names use `Sphere.016`-style auto-suffixes even when there's a meaningful name on the parent node.** E.g. `meshes[0].name = "Sphere.016"` but the node it's attached to is `ArmL`. Set `mesh.name = node.name` on export, or in Blender duplicate-rename the mesh data-block alongside the object before export. The current state makes `gltfpack`/`gltf-transform` diffs unreadable.

- **`metallicFactor: 0, roughnessFactor: 0.5`** is the Blender default. None of the materials were authored — they're all "fresh material" stubs. The gold coin should at minimum have metallicFactor: 1.

- **Chest `ChestBase` node has a `mesh: 4` (the outer cube) AND four children with their own meshes — the base is drawn twice if a kid spawns inside it.** Verify whether `ChestBase`'s own mesh should be empty (just an organizational parent) or whether the children should be siblings.

- **`Mascot` root node has no `mesh` field** — purely organizational `children: [0..17]`. Correct, but inconsistent with `PalmTrunk` (which has both `mesh: 7` and children). Pick a convention.

- **Bunny `Body` ear inner geometry is scaled differently than the outer ear (`EarL_Inner` Z-scale 0.5 vs `EarL` Z-scale 1.0).** Fine artistically, but if the kid presses against the ear in 3D, the inner pink will z-fight at the boundary unless `EarL_Inner.z` translation is offset more than the current 0.04 — which is too small for a stretched mesh. Z-fighting risk on mid-range Android GPUs (24-bit depth buffer).

- **License files for Kenney assets are committed** (`License.txt` x2) but no top-level `THIRD_PARTY_LICENSES.md` aggregates them. Compliance trail for a kid-shipping product should be one click, not a treasure hunt.

- **`grass_foreground.png`** is 1280×1472 — odd aspect ratio that doesn't tile and won't power-of-two cleanly on mobile. Will trigger Godot's `import_etc2_astc` re-sample on import. Resize to 1280×1024 or 1024×1024.

## Manual test log

Subagent has no graphical session — manual screenshot capture against a running Godot instance was not possible from this worktree. All findings derived from static inspection of glTF JSON, code references, and filesystem state. **Verification gap:** I did not visually confirm whether `WorldRenderer._apply_toon_to_prop` actually recovers per-material colour from Godot's glTF import, or whether all 21 prop materials render identically grey. Recommend a manual run with one of the existing 7 props (`palm` is the visually richest) to confirm whether `StandardMaterial3D.albedo_color` survives the import pipeline.

Static-inspection steps performed:
1. Listed `data/models/props/` — 7 `.gltf`+`.bin` pairs plus `props_master.blend` (100 KB).
2. Listed `data/models/mascot/` — `bunny.gltf` (22 KB) + `bunny.bin` (170 KB) + `bunny.blend` (138 KB).
3. Parsed every prop glTF and the mascot glTF — extracted material colour factors, node graph, mesh names, accessor counts, double-sided flags.
4. Diffed `PROP_GLTF_MAP` (`world_renderer.gd:37-74`) against `ls data/models/props/*.gltf` — 23 mapped paths have no file; one mapped name (`fence_segment.gltf`) mismatches the on-disk `fence.gltf`.
5. `rg "bunny" src/ tests/` and `rg "models/kenney" src/ tests/` — confirmed mascot glTF and Kenney libraries are unwired.
6. `rg "data/textures/" src/` — only `landing_screen.gd` loads any textures; particle and UI texture sets are unused.
7. `du -sh` on Kenney + particle directories to confirm disk waste.
8. Cross-checked `mascot.gd:_draw()` against the `data/models/mascot/bunny.gltf` — mascot UI still 2D primitives.

## Recommendations

**P0 — release-blocking (do this before any kid touches a build):**
1. Generate the 23 missing prop glTFs (or trim `PROP_GLTF_MAP` to only the seven that exist and rebuild the world spec library). Until then, three of the four seed worlds render as grey-box dioramas.
2. Fix the `fence_segment.gltf` → `fence.gltf` mismatch — one line in `world_renderer.gd:53`.
3. Author real `baseColorFactor` values on every material in `props_master.blend` and re-export. At minimum: `PropGold` → metallic 1.0 + gold colour; `PropCrystal` → cyan + emission; `PropLeaf` / `PropGrass` → green; `PropMoss` → moss-green; `PropWood` / `PropWoodDark` → brown; `PropStone` → grey is fine; `PropTrunk` → bark-brown. Same for the 5 `Mascot*` materials. Confirm Godot imports the colour into `StandardMaterial3D.albedo_color`.
4. Wire `bunny.gltf` into `mascot.tscn` — replace the 2D `_draw()` Control with a `SubViewport` 3D mascot or a baked sprite-sheet generated from the glTF. The 4-meter authoring scale needs to come down to roughly 0.05 to fit a 220 px UI region.

**P1 — high before public beta:**
5. Set `doubleSided: false` on at least the closed-geometry materials (`PropWood`, `PropStone`, `MascotPeach`, `MascotWhite`, `MascotNose`); keep it true for `PropLeaf`, `PropGrass`, `MascotPink`-cheeks. Roughly half the materials.
6. Rename mesh data-blocks in Blender so they match their parent object: `EarL`, not `Sphere.016`. Re-export.
7. Find or remove `props_v2.blend` — either commit it or update the review brief.
8. Re-encode `data/textures/landing/cloud_*.png` to WebP or PNG8 (save ~6 MB of landing payload).

**P2 — repo hygiene:**
9. Delete Kenney FBX, OBJ, Previews, Preview.png, Sample.png, .url shortcuts (~14 MB saved). Keep GLB + License.txt. Add a `THIRD_PARTY_LICENSES.md` aggregator at repo root.
10. Delete `data/textures/particles/PNG (Black background)/` (4.2 MB, marketing-only).
11. Confirm Kenney accessibility props (`aid-*`, `wheelchair-*`) are on the product roadmap; if not, remove.
12. Share palm leaf mesh data across the 6 instances — convert to glTF `EXT_mesh_instancing` or pre-merge in Blender.
13. Strip TEXCOORD_0 from prop glTFs until textures land (saves ≈200 bytes/mesh × ≈50 meshes ≈ 10 KB and reduces import time).

**P3 — verify in-engine (manual session required):**
14. Open Godot, instantiate each of the 7 existing props in a debug scene, confirm: (a) `_apply_toon_to_prop` reaches the correct colour, (b) `spawn_crystal` is upright (quaternion near-singularity check), (c) `palm` leaves don't z-fight, (d) `bunny.gltf` can be imported and animates a test wave.

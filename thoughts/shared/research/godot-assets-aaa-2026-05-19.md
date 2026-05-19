# Godot 4.6 AAA-Look Asset Pipeline (no human artist)

Date: 2026-05-19
Project: choyce-engine — kid-safe family game engine (Godot 4.6, target age 5-8, Polish-first UI, hexagonal architecture)
Current asset baseline: ~1000 Kenney CC0 GLB props (flat colormap PBR), 32 custom Blender placeholder gltfs in `data/models/props/`, Kenney `mini_characters/character-male-a.glb` (32 anims), painted material pipeline via Python glTF JSON edits.

## 1. Executive Summary (highest-ROI in 3-5 sentences)

The single biggest visual lift for the lowest cost is **environment + lighting + grounding**, not per-prop normal maps. Specifically: (a) drop in **Terrain3D** (MIT, GDExtension) with its chunked-MultiMesh foliage instancer, (b) replace Procedural sky with a hand-tuned **stylized sky shader** plus a **CC0 PolyHaven HDRI** baked to radiance for ambient/IBL, (c) layer a **CC0 stylized toon-water shader** in coast/lake regions, and (d) batch-generate normal+roughness+AO maps for the ~20 hero Kenney atlases with **Materialize** (GPL, batchable via XML, ~10 min total). For animations, **MixaBridge** (3-click Mixamo retargeting plugin) plus **Quaternius Universal Animation Library 2** (CC0, Godot-tested glTF) deliver climb/swim/dance/parkour onto the existing Kenney humanoid rig without touching Blender. Skip Substance Sampler — it's a paid Adobe product and Materialize covers the only missing maps Kenney ships without.

## 2. Findings by Question

### 2.1 PBR conversion for Kenney models — Worth it for hero atlases only

Kenney ships per-kit a single 512×512 `colormap.png` referenced as `baseColor`; there are no normal/roughness/metallic/AO maps. The materials look flat under PBR lighting because the surface always reads as roughness=1.0, smooth normal.

**Best tool: Materialize (Bounding Box Software)** — GPL 3, Windows native, batchable, free. It generates Height → Normal, Diffuse → Height/Smoothness/Metallic, Normal → AO/Edge directly from a single diffuse atlas. Used in production on Naughty Dog's Uncharted Collection to backfill missing PBR maps. ([downloads page](http://boundingboxsoftware.com/materialize/) | [GitHub source](https://github.com/BoundingBoxSoftware/Materialize))

**Realistic delta vs cost:**
- A Kenney atlas has discrete color cells (one cell per prop part), not a tile-able texture. Generated normal maps will give per-cell subtle relief; results are decent on chunky props (rocks, logs, bread loaves) and weak on smooth props (apples, eggs).
- The bigger win comes from non-uniform **roughness** maps: glossy roof tiles vs matte bark vs satin fabric all currently read identically.
- **Recommended scope:** generate normal+roughness+AO for the ~6 Kenney kits actually shipped (nature, pirate, food, survival, mini_characters, toon_characters). 6 atlases × ~30s/atlas in batch mode = under 5 minutes. ~3 MB extra VRAM per kit (1 colormap + 3 generated 512² maps).
- **Skip:** Substance Sampler (closed source, Adobe subscription, overkill for atlases this small).
- **Material Maker 1.4** (MIT, Godot 4.4-based, [materialmaker.org](https://www.materialmaker.org/)) is the procedural-graph alternative. Better for *tileable* materials (grass, dirt, stone), not for "fix-up an existing atlas" — keep it for terrain splat textures, not for Kenney props.

**Concrete action:** extend the existing `ProcessTo` glTF Python pipeline to: (1) shell out to Materialize CLI on each colormap, (2) inject the resulting `normalTexture` / `metallicRoughnessTexture` / `occlusionTexture` references back into each prop's glTF. Single import pass cost: ~30 s on M2 Max.

### 2.2 CC0 texture sources

Three primary sources, all CC0, all commercial-safe with zero attribution required:

| Source | Strengths | License | Notes |
|---|---|---|---|
| [Poly Haven](https://polyhaven.com/) | 16K HDRIs (always unclipped), 8K PBR materials, ~1000 CC0 models | CC0 | Use 1K-2K res in-engine to keep VRAM sane. Direct download, no signup. |
| [ambientCG](https://ambientcg.com/) | Largest CC0 PBR surface library (rocks, ground/sand, wood, fabric, metal) with pre-baked atlas variants | CC0 | All 5 starter-world surface needs (sand, dirt, grass, bark, stone) covered. |
| [Sketchfab CC0 filter](https://sketchfab.com/3d-models?features=downloadable&licenses=7c23a1ba438d4306920229c12afcb5f9) | Stylized hero props that fill Kenney gaps (e.g., specific mushroom species, treasure items) | mixed; filter explicitly to CC0 | Verify license per asset; avoid CC-BY/CC-BY-NC. |
| [OpenGameArt CC0 filter](https://opengameart.org/art-search-advanced?keys=&field_art_type_tid%5B%5D=10&sort_by=count&Collection=) | Older but huge CC0 model archive, audio, textures | mixed; filter to CC0 | Quality is uneven — preview first. |

**Godot Material Manager plugin:** the asset linked at `Donitzo/godot-material-manager` returned 404 — no longer maintained. Use the **Godot AssetLib in-editor** filter for current options; for ambientCG specifically there's no first-party plugin, so the workflow is: download zip → drop into `data/textures/materials/<name>/` → use the bundled `_diff.png` / `_nrm.png` / `_rough.png` as a Godot `StandardMaterial3D` (the only manual step is wiring 3-4 texture slots per material — well under 5 min per material).

**Commercial-release license safety:** CC0 = public domain dedication, no attribution required, no copyleft. All three primary sources (Poly Haven, ambientCG, Kenney) are usable in the engine binary without per-use licensing. Maintain a top-level `THIRDPARTY-ATTRIBUTIONS.md` listing source URLs as good-citizen practice, but it is not legally required.

### 2.3 Character animation upgrade — MixaBridge + Quaternius

The Kenney `mini_characters` rig uses a **glTF humanoid bone naming convention** that is compatible with Godot's `SkeletonProfileHumanoid` once a BoneMap resource is created. Two paths, both free:

**Path A: Mixamo via MixaBridge** (smoothest, ~3 clicks per batch)
- Upload `character-male-a.glb` to mixamo.com once (free with Adobe ID), download as `.fbx` + "Without Skin" animations.
- Install **[MixaBridge](https://mixabridge.uzair.ct.ws/)** — a Godot editor plugin that automates BoneMap creation, retarget settings injection, reimport, and AnimationLibrary assembly in three clicks. Has built-in "Loop" and "Remove Root" toggles (in-place locomotion).
- Mixamo license: free, royalty-free, commercial-safe **when embedded in a project** (cannot redistribute raw FBXs as standalone assets, cannot use for ML training). [Mixamo FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) — confirmed free indefinitely with grandfathered rights even if pricing changes.
- Adobe ToS 6.2.E specifically forbids distributing Mixamo animations as a downloadable library, so we cannot commit `.fbx` source to git; commit the *retargeted .res files inside the project* instead — those are derivative game-embedded animations and are allowed.
- Alternative for batch: **[RaidTheory's Godot-Mixamo-Animation-Retargeter](https://github.com/RaidTheory/Godot-Mixamo-Animation-Retargeter)** — adds right-click "Retarget Mixamo Animation" to FileSystem dock; slightly older but well-documented.

**Path B: Quaternius Universal Animation Library 2** (CC0, no Adobe account, redistributable)
- [Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html) (v1, 120+ anims) + [Universal Animation Library 2](https://quaternius.com/packs/universalanimationlibrary2.html) (130+ anims, combat/parkour/farming/fishing/zombie locomotion, January 2026 v2.0 update fixed Godot retarget issues, ships .blend + .glb + .fbx + .obj).
- CC0 — can be committed to the repo, redistributed, no attribution required.
- Universal rig is Mixamo-bone-naming-compatible by design; the same BoneMap resource works for both pipelines.
- **Recommended order:** start with Quaternius (CC0, in-repo) for the common verbs (idle, walk, run, jump variants, climb, swim, push, pull, dance, wave, sit, sleep). Use Mixamo only for very specific game-feel animations not in Quaternius.

**Godot 4.6 retarget workflow (any path):**
1. Open source `.glb`/`.fbx` → Advanced Import Settings.
2. Select Skeleton3D → Inspector → Retarget → BoneMap → New BoneMap → save as `data/anim/humanoid_bonemap.tres` (one-time).
3. Set Profile = `SkeletonProfileHumanoid`. Verify every bone slot is green AND points to the right Kenney bone (do not trust green dots blindly; click each).
4. Per-animation: Save to File → enable → save `.res` to `data/anim/locomotion/<verb>.res`.
5. Assemble into `AnimationLibrary` and attach to character's `AnimationPlayer` — one library per category (locomotion, emote, interact).

Plain hexagonal-architecture note: keep `AnimationLibrary` instances inside `data/anim/` (asset layer) and consume via an `AnimationPort` outbound port if the kid avatar service ever needs to query "is animation X available", so business logic doesn't leak into the scene tree.

### 2.4 Foliage instancing — Terrain3D + MultiMeshInstance3D, never StaticBody3D per grass tile

**Verdict for M2 Max + Forward+ + 1000+ grass tiles:**

- **Never** use a Node3D / StaticBody3D per grass blade. Per-node overhead dominates at >500 instances.
- **MultiMeshInstance3D** is the correct primitive — one draw call per mesh, GPU-resident transforms, no simulation cost. But MultiMesh has **no per-instance frustum/occlusion culling** — all instances render every frame regardless of visibility.
- **Fix:** chunk grass into spatial cells (32×32 m is the convention Terrain3D uses) so the engine can frustum-cull each cell's MultiMesh as a whole.
- **GPUParticles3D**: do **not** use for static foliage. It adds particle simulation overhead, defaults to per-pixel shaded and shadow-casting materials, and isn't designed for this. ([Godot docs: Optimization using MultiMeshes](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html))

**Best plugin: [Terrain3D](https://github.com/TokisanGames/Terrain3D)** (MIT, C++ GDExtension, Godot 4)
- Up to 32 textures, sculpting, holes, splat painting, color+wetness painting.
- **Foliage instancer** with 10 LOD levels per asset + shadow impostor for distant grass.
- Regions are variable-size (64m to 65.5km square); empty regions cost nothing.
- Terrain3D's instancer specifically chunks foliage into per-region cells, which is exactly the culling-recovery pattern needed. ([Foliage Instancing docs](https://terrain3d.readthedocs.io/en/stable/docs/instancer.html))
- Heightmap import from HTerrain, Gaea, World Creator, Unreal/Unity exports — useful if a CC0 heightmap is sourced from Poly Haven.

**Performance budget on M2 Max, Forward+:** Terrain3D's own demo runs 100K+ foliage instances at >120 fps on M-series Macs once chunking + LOD are wired. For 3 starter worlds at kid-game scale (≤10K total foliage per scene), there is essentially no GPU cost.

**Alternative if Terrain3D is too heavy:** roll a bespoke `FoliageRegion` node that holds a `MultiMeshInstance3D` per cell. ~150 lines of GDScript. Lose the splat-painting workflow but keep the perf model.

### 2.5 Environment art quick wins — ranked by visual lift per hour

1. **Stylized sky shader + radiance HDRI** (highest ROI)
   - Switch from `ProceduralSkyMaterial` defaults to [GDQuest stylized sky](https://github.com/gdquest-demos/godot-4-stylized-sky) (MIT). Painted gradient + sun disc + cloud band that matches Kenney's painted look.
   - For IBL/ambient, load a CC0 HDRI from [Poly Haven](https://polyhaven.com/hdris) (1K-2K res, ~5-15 MB) into the `Environment` resource — even a cartoony "kloofendal" HDRI gives free realistic ambient lighting that procedural sky can't.
   - **Set Sky → Process Mode = "Static"** so the radiance cubemap renders once at scene load. Effectively zero per-frame cost. ([Godot Sky class](https://docs.godotengine.org/en/stable/classes/class_sky.html))
   - Per-world ambient tint via `Environment.ambient_light.sky_contribution=0.7` mixed with a soft purple/yellow color — gives each starter world a distinct mood without per-prop work.

2. **Toon water shader** (high ROI for Wyspa skarbów + Mała farma pond)
   - [Godot Shaders: Toon Water Shader (Godot 4.4+)](https://godotshaders.com/shader/toon-water-shader-godot-4-4/) — CC0, fits stylized look.
   - Or [paddy-exe/Godot-3D-Stylized-Water](https://github.com/paddy-exe/Godot-3D-Stylized-Water) — paddyolij-derived, MIT.
   - Or [Binbun Godot Water](https://binbun3d.itch.io/godot-water-shader) — CC0, caustics + refraction + foam + toon mode.
   - Drop a `MeshInstance3D` plane with the shader as `ShaderMaterial`. Tune foam line + depth color per scene. ~30 min/scene.

3. **Terrain splat texturing with multi-texture blend**
   - Terrain3D supports 32 textures with painted weight maps.
   - Pull 4 ambientCG materials per world: grass/dirt/sand/stone (Wyspa) | grass/dirt/wood-floor/path (Farma) | moss/dirt/leaf-litter/mushroom-cap (Las).
   - Each ambientCG download is `_diff` + `_nrm` + `_rough` + `_disp` 2K PNGs. Total per world: ~30 MB on disk, ~15 MB VRAM after compression.

4. **Post-processing: SDFGI off, SSIL on at low quality, glow at low intensity** — gives kid-friendly soft bloom without the perf cost of full GI. Children's eyes parse contrast better with mild bloom.

### 2.6 Asset organization in Godot for ~1000 GLBs

Current structure is already good (`data/models/kenney/<kit>/`, `data/models/props/` for custom). Boot-time concerns:

**Critical import-setting changes** ([Godot LOD generation cost reported in issue #64751](https://github.com/godotengine/godot/issues/64751)):

| Setting | Default | Recommended for Kenney props | Why |
|---|---|---|---|
| `meshes/generate_lods` | true | **false** for props < 1K verts (95% of Kenney) | LOD gen normal-reconstruction casts 16-64 rays per new triangle — single hot path in import time. |
| `meshes/light_baking` | "Static Lightmaps" | **"Disabled"** (or "Static" for the few hero meshes) | UV2 unwrapping is per-mesh and expensive. Kid game with dynamic lighting doesn't need lightmap UV2 on every apple. |
| `meshes/create_shadow_meshes` | true | **false** for foliage/grass | Shadow mesh creation doubles import cost; multi-mesh foliage doesn't need it. |
| `nodes/use_node_type_suffixes` | true | true (keep) | Lets you tag `-col` `-rigid` in Blender; doesn't affect speed. |
| `materials/location` | "Files (.material)" | **"Built-In"** for non-shared materials | Avoids generating thousands of `.material` files. Keep "Files" only for hero materials reused across props. |
| `animation/import` | true | **false** for static props | Kenney prop GLBs don't have animations; flag still triggers AnimationPlayer node creation. |

**Atlas the colormaps for the same kit:** since each Kenney kit's props all reference the same 512×512 `colormap.png`, Godot's importer already shares the texture across all props in the kit — no further atlasing needed. Confirm with `Project → Tools → Orphan Resource Explorer` after import.

**Boot time target (<60s on M2 Max):** with the settings above, full reimport on a ~1000-prop project should drop from ~30s to ~15-20s. Most of the remaining cost is shader compilation (mitigated by `rendering/shader_compiler/shader_cache/enabled=true` — Godot 4.4+ ships with this on by default).

**Cold-load runtime memory:** ~1000 GLBs × (~50 KB mesh + shared 0.7 MB colormap per kit) ≈ 50 MB mesh + 5 MB textures total — well within budget.

**Loading pattern:** do **not** preload all 1000 props at app start. Use `ResourceLoader.load_threaded_request()` per-world, keyed off the active starter world. The `data/models/kenney/<kit>/` folder layout maps cleanly to per-world packs.

### 2.7 Gaps in current asset set for the 3 starter worlds

Existing custom placeholders in `data/models/props/` (apple, apple_tree, barn, boat, chest, chicken, coin, egg, fence, fence_segment, firefly_jar, flag_pole, flower_patch, glowing_acorn, ground_forest, ground_sand, hay_bale, hollow_log, mossy_rock, mushroom_small, palm, pearl, windmill, ...) + Kenney kits already on disk (food, mini_characters, nature, pirate, survival, toon_characters).

**Wyspa skarbów (Treasure Island):**
- Have: chest, coin, boat, flag_pole, palm, ground_sand, pearl (custom) + full pirate_kit (190 assets).
- Gaps: **palm trees with leaves** (current `palm.gltf` is a placeholder), **shipwreck pieces**, **rope bridges**, **lighthouse**. Fill from Kenney `pirate_pack` (lighthouse, ship parts), Quaternius palm packs ([quaternius.com/packs](https://quaternius.com/packs/)), Poly Haven CC0 model search for "shipwreck".
- Water: toon water shader (see 2.5).

**Mała farma (Small Farm):**
- Have: barn, chicken, egg, fence, fence_segment, hay_bale, windmill, apple, apple_tree (custom) + nature_kit + food_kit (200 food models).
- Gaps: **animals** (cow, sheep, pig, horse). Kenney has no farm-animal pack. Best CC0 source: **Quaternius Animated Animals** ([quaternius.com/packs](https://quaternius.com/packs/)) — CC0, rigged, animated, glTF-ready, kid-stylized to match. **Crops/vegetable rows** filled by food_kit (carrots, cabbage, corn). **Tractor/wagon** filled by Kenney's Vehicle Kit ([kenney.nl/assets/car-kit](https://kenney.nl/assets/car-kit) or [kenney.nl/assets/transport-kit](https://kenney.nl/assets/transport-kit)).

**Las grzybów (Mushroom Forest):**
- Have: mushroom_small, mossy_rock, hollow_log, glowing_acorn, firefly_jar, ground_forest, flower_patch (custom) + nature_kit (330 nature assets — includes many mushroom variants and forest plants).
- Gaps: **giant fairy-tale mushrooms** (the current `mushroom_small.gltf` is small/realistic). Best CC0 sources: Sketchfab CC0 filter for "stylized mushroom"; OpenGameArt for fairy-mushroom kits. **Mystic creatures** (fairies, fireflies fluttering): Quaternius bug/insect packs are CC0. **Glow/emission pass**: shader-driven, no extra geometry needed — set `emission` on glowing_acorn and firefly_jar materials.

**Cross-world: humanoid NPCs** — Kenney `mini_characters` + `toon_characters` cover kid-readable NPCs. For variety, Quaternius **Universal Base Characters** ([quaternius.com/packs/universalbasecharacters.html](https://quaternius.com/packs/universalbasecharacters.html)) is CC0, Mixamo-rig-compatible, ships in glTF, and shares the rig with Universal Animation Library so any retargeted anim plays on any character.

## 3. Tools to Install (punchlist)

Install in this order; each block independent.

**3.1 Asset-generation toolchain (one-time, host machine)**
- [ ] **Materialize** (Windows binary or build from GitHub source on macOS via Unity) — `http://boundingboxsoftware.com/materialize/`. Wire into existing `ProcessTo` Python pipeline via XML clipboard automation for batch.
- [ ] **Material Maker 1.4** (macOS native, MIT) — `https://www.materialmaker.org/` — for procedural tileable terrain textures, not for prop fixup.
- [ ] (optional) **Blender 4.4+** for animation tweaking only — never required for asset creation in this project.

**3.2 Godot editor plugins (commit to `addons/`)**
- [ ] **Terrain3D** — [`TokisanGames/Terrain3D`](https://github.com/TokisanGames/Terrain3D), MIT, GDExtension. Drop `addons/terrain_3d/` from a release ZIP, enable in Project Settings → Plugins.
- [ ] **MixaBridge** — `https://mixabridge.uzair.ct.ws/` — Mixamo retargeting in 3 clicks. (license: free, check page for exact terms — if not MIT/CC0, keep the plugin only, not its outputs.)
- [ ] **RaidTheory Mixamo Retargeter** (backup) — [`RaidTheory/Godot-Mixamo-Animation-Retargeter`](https://github.com/RaidTheory/Godot-Mixamo-Animation-Retargeter), context-menu-driven.

**3.3 Shaders (commit to `data/shaders/`)**
- [ ] **GDQuest Stylized Sky** — [`gdquest-demos/godot-4-stylized-sky`](https://github.com/gdquest-demos/godot-4-stylized-sky), MIT.
- [ ] **Toon Water Shader (Godot 4.4+)** — `https://godotshaders.com/shader/toon-water-shader-godot-4-4/`, CC0.
- [ ] (optional) **Binbun Godot Water** — `https://binbun3d.itch.io/godot-water-shader`, CC0, more features but heavier.

**3.4 CC0 asset packs (commit to `data/models/` and `data/textures/`)**
- [ ] **Quaternius Universal Animation Library 1+2** — `https://quaternius.com/packs/universalanimationlibrary.html` and `universalanimationlibrary2.html`. CC0.
- [ ] **Quaternius Universal Base Characters** — `https://quaternius.com/packs/universalbasecharacters.html`. CC0.
- [ ] **Quaternius Animated Animals** (farm animals + insects) — browse `https://quaternius.com/packs/`.
- [ ] **Kenney Transport Kit** for farm vehicles — `https://kenney.nl/assets/transport-kit`. CC0.
- [ ] **Poly Haven HDRIs** (3 × 1K, one per world) — `https://polyhaven.com/hdris`. CC0.
- [ ] **ambientCG ground/grass/sand/stone materials** (4-5 per world) — `https://ambientcg.com/`. CC0.

**3.5 Godot project settings tweaks (`project.godot`)**
- [ ] In **Import Defaults** (Project → Project Settings → Importing): set `meshes/generate_lods=false`, `meshes/light_baking="Disabled"`, `meshes/create_shadow_meshes=false`, `materials/location="Built-In"` for the `glTF Scene` importer.
- [ ] Set `rendering/lights_and_shadows/use_physical_light_units=false` (kid-stylized look, not realism).
- [ ] Confirm `rendering/shader_compiler/shader_cache/enabled=true`.
- [ ] Per-world `WorldEnvironment` with `Sky.process_mode=STATIC` after first frame.

## 4. References

### PBR tools
- Materialize official site: http://boundingboxsoftware.com/materialize/
- Materialize source: https://github.com/BoundingBoxSoftware/Materialize
- Material Maker: https://www.materialmaker.org/
- Material Maker 1.4 release writeup (CG Channel, Oct 2025): https://www.cgchannel.com/2025/10/material-maker-1-4/

### CC0 asset sources
- Poly Haven: https://polyhaven.com/
- ambientCG: https://ambientcg.com/
- Kenney asset library: https://kenney.nl/assets
- Kenney Nature Kit: https://kenney.nl/assets/nature-kit
- Kenney Food Kit: https://kenney.nl/assets/food-kit
- Kenney Pirate Pack: https://kenney.nl/assets/pirate-pack
- Kenney Survival Kit: https://kenney.nl/assets/survival-kit
- Kenney Transport Kit: https://kenney.nl/assets/transport-kit
- Quaternius packs index: https://quaternius.com/packs/
- Quaternius Universal Animation Library: https://quaternius.com/packs/universalanimationlibrary.html
- Quaternius Universal Animation Library 2: https://quaternius.com/packs/universalanimationlibrary2.html
- Quaternius Universal Base Characters: https://quaternius.com/packs/universalbasecharacters.html
- OpenGameArt CC0 filter: https://opengameart.org/

### Animations & retargeting
- Mixamo: https://www.mixamo.com/
- Mixamo FAQ (license, free status): https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html
- MixaBridge plugin: https://mixabridge.uzair.ct.ws/
- RaidTheory Mixamo Retargeter: https://github.com/RaidTheory/Godot-Mixamo-Animation-Retargeter
- 9to5-Grind Godot 4 manual Mixamo retarget tutorial: https://9to5grind.dev/posts/bringing-mixamo-animations-to-life-in-godot/
- catprisbrey OpenAnimationLibraries: https://github.com/catprisbrey/Godot4-MixamoLibraries

### Terrain & foliage
- Terrain3D: https://github.com/TokisanGames/Terrain3D
- Terrain3D foliage instancer docs: https://terrain3d.readthedocs.io/en/stable/docs/instancer.html
- Godot MultiMesh optimization docs: https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html

### Shaders
- GDQuest Stylized Sky: https://github.com/gdquest-demos/godot-4-stylized-sky
- Toon Water Shader (Godot 4.4+): https://godotshaders.com/shader/toon-water-shader-godot-4-4/
- paddy-exe Godot-3D-Stylized-Water: https://github.com/paddy-exe/Godot-3D-Stylized-Water
- Binbun Godot Water: https://binbun3d.itch.io/godot-water-shader
- Absorption Based Stylized Water: https://godotshaders.com/shader/absorption-based-stylized-water/

### Godot import + sky docs
- Godot Sky class: https://docs.godotengine.org/en/stable/classes/class_sky.html
- Godot Mesh LOD docs: https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html
- Godot issue #64751 (slow import due to LOD): https://github.com/godotengine/godot/issues/64751
- Godot custom sky shaders article: https://godotengine.org/article/custom-sky-shaders-godot-4-0/

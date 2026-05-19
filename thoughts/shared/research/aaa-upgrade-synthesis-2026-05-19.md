---
date: 2026-05-19
researcher: claude (architecture)
project: choyce-engine
engine: Godot 4.6.1
target: M2 Max + iPad-class tablet, 60 fps, kid-safe age 5-8, Polish locale
sources:
  - thoughts/shared/research/godot-graphics-aaa-2026-05-19.md
  - thoughts/shared/research/godot-assets-aaa-2026-05-19.md
  - thoughts/shared/research/godot-mechanics-aaa-2026-05-19.md
  - inline: Godot 4.6 physics (Jolt, joints, PhysicsMaterial, SoftBody3D, Area3D buoyancy)
status: synthesis — ready for backlog grooming
---

# AAA Upgrade Roadmap — Unified Synthesis

Three parallel deep-research passes (graphics, assets, mechanics) converge on the same diagnosis: the current build is a **tech demo**, not a kid game. The fastest path to "Astro Bot diorama" feel is not realism — it is **stylized polish + grounded mechanics**, layered in 3 sequenced waves over ~9-12 dev days. No paid tools. No PBR re-authoring. No human artist.

---

## Executive summary across all 3 axes

| Axis | Single biggest win | Cost | Risk |
|---|---|---|---|
| Graphics | MetalFX Temporal upscaling at 0.67 scale on M-series — reclaims ~30-40% GPU and improves AA simultaneously | S | low (Apple-only, gated by `OS.has_feature`) |
| Assets | Terrain3D + stylized sky + CC0 HDRI for IBL — environment is highest visual-lift-per-hour | M | low (Terrain3D is MIT, GDExtension drop-in) |
| Mechanics | SpringArm3D + AnimationTree + Resource-driven rules engine — turns "movement demo" into "you played a game" | M-L | medium (player_controller refactor blast radius) |
| Physics | Switch 3D physics engine to **Jolt** (Godot 4.4+ built-in) — same scenes, 2-5× faster, fewer character-controller ghost bugs | S | low (one project setting, gracefully falls back) |

The three "hero" items above compose into the same Wave 1 because they have **no overlap** in code touched: graphics edits Environment + shader, assets adds plugin + data, mechanics rewrites player_controller. Three workers can ship them in parallel.

---

## Cross-cutting themes (where 2+ agents agree)

### 1. Skip realism — double down on stylized
- Graphics: skip SDFGI/VoxelGI (4.6 regression + Apple Silicon cost), keep flat Kenney albedo, evolve toon shader.
- Assets: skip Substance Sampler (paid + overkill for atlases), skip pure PBR conversion for non-hero props.
- Mechanics: skip combat NPCs, skip damage HP, use puzzle/rhythm/collection loops.
- **Action**: lock the art direction as "Astro Bot diorama / Ghibli toon" — kill any PBR/realism aspiration in the backlog.

### 2. Environment > per-prop work
- Graphics agent's #2/#3 wins are sky + fog + shadow tuning (environment).
- Assets agent's #1 win is Terrain3D + stylized sky + CC0 HDRI (environment).
- Mechanics agent's NPC + interactable systems need NavigationRegion3D baked at world-load (environment).
- **Action**: Wave 1 builds the environment layer first. Per-prop polish (Materialize normal maps) is Wave 3, not Wave 1.

### 3. AnimationTree unblocks 4 features
Mechanics calls for AnimationTree to enable hover/double-jump/swim/climb. Assets calls for AnimationLibrary expansion via Quaternius/MixaBridge. Graphics is silent on animation. The dependency is: **AnimationTree must exist before any Mixamo/Quaternius retarget pays off** — otherwise we still call `_play_anim("name")` and the new clips don't blend.
- **Action**: AnimationTree refactor (M, 1 day) must land before Quaternius animation library import (S, ½ day).

### 4. Composition-root CI gate is load-bearing
Each axis adds new ports/adapters:
- Mechanics: RulesRuntimePort, NavigationPort, NpcAgentPort, MusicDirectorPort.
- Graphics: none — pure asset/shader edits.
- Assets: TerrainPort (optional — could go straight to Terrain3D plugin).
- **Action**: the existing Wave B composition-root gate (`.github/workflows/composition-root-gate.yml`) catches missing wires. No new infra needed; just add KEY_* entries.

### 5. Cache + boot-time hygiene
Assets agent flags glTF importer defaults as wasting boot time (LOD gen, light_baking UV2, shadow_meshes on foliage). Current run.sh already wipes cache on glTF mtime change. The cheap win is changing **import defaults** so re-imports are 2× faster.
- **Action**: edit project.godot import defaults — Wave 0 prerequisite, ~10 min, single commit.

---

## Wave structure

## 4th axis — Game physics (added in revision)

Current 3D physics: Godot Physics (the legacy in-process engine). CharacterBody3D walks on a flat plane; no rigid bodies in the scene; no joints; no buoyancy; no breakables. Adding physics turns kid props from **scenery → toys** — kick a ball, knock crates, bounce on a trampoline, see-saw tilts under weight, ragdoll bunny tumbles when player runs through it. This is the single biggest "feels like a real world" upgrade after the camera/anim/rules trio.

### Jolt Physics swap (Wave 0 — single project setting)
Godot 4.4+ ships **Jolt Physics** as a built-in 3D physics option. It is 2-5× faster than Godot Physics on the same scenes, has materially better CharacterBody3D ghost-collision behavior, and is the recommended default for new 3D projects per the Godot blog. Switch via `Project Settings → Physics → 3D → Physics Engine = "Jolt Physics"`. Single line in `project.godot`. CharacterBody3D + StaticBody3D + Area3D APIs unchanged.

**Caveats**:
- SoftBody3D requires Godot Physics — if we want soft cloth/jelly later, layer it via a per-soft-body override (Jolt for the rest, Godot for cloth). Wave 3 concern only.
- Slight numerical drift on existing collision shapes — re-run smoke test after swap.

### Physics-driven mechanics (Wave 2.K, ~1.5 days)
Each is a RigidBody3D `.tscn` + 30-line script. Composable into worlds via existing world template JSON `objects` array.

| Toy | Node | Kid-feel | Implementation |
|---|---|---|---|
| **Kickable ball** | RigidBody3D + SphereShape3D | universal joy | mass 0.5, PhysicsMaterial bounce 0.6, friction 0.4 — Player on collision adds `apply_central_impulse(velocity.normalized() * 6.0)` |
| **Breakable crate** | RigidBody3D + BoxShape3D, child `pieces.tscn` | satisfying smash | on `body_entered` if relative velocity > 4 m/s → queue_free, spawn 6 small RigidBody3D fragments (each 0.2s lifetime fade) |
| **Trampoline** | StaticBody3D + Area3D detector | repeat-bounce loop | on `body_entered` set `velocity.y = JUMP_VELOCITY * 1.8`, play boing SFX + squash anim |
| **See-saw / log bridge** | RigidBody3D + HingeJoint3D anchored to StaticBody3D | weight-shift puzzle | hinge limit -30°..+30°, friction 0.2, mass 8 so kid tips it visibly |
| **Pull-rope chain** | 6× RigidBody3D capsules + 5× PinJoint3D | physics-y delight | mass cascade 4→0.5; PinJoint3D bias 0.3; last segment is grab target |
| **Wind-blown leaves / cloth flag** | RigidBody3D (flag) + HingeJoint3D + script applies sinusoidal force | atmosphere | force = `Vector3(sin(time)*0.5, 0, cos(time)*0.5)` per frame |
| **Buoyancy in water_zone** | Area3D `gravity = -9.8` upward + linear_damp 4.0 | swim/float feel | objects entering water_zone get upward gravity override; CharacterBody3D swap to swim mode (mechanics §7) is separate |
| **Domino chain / stackable blocks** | RigidBody3D + BoxShape3D | classic toy box | mass 1, friction 0.6, default linear_damp 0.3 |
| **Ragdoll bunny on knockdown** | Skeleton3D + PhysicalBoneSimulator3D | comedy beat | on player collision velocity > 6 → call `physical_bones_start_simulation()` for 2s, then `stop()` and re-anchor |
| **Slingshot / launcher** | StaticBody3D + Area3D trigger + Tween scaled spring | platforming verb | enter → tween squash → impulse player upward 14 m/s |

**Architecture** (hex-clean):
- Domain: `PhysicsToyKind` enum, `PhysicsImpulse` value type.
- Port: `PhysicsToyPort.spawn_toy(kind, position, params)` outbound.
- Adapter: `GodotPhysicsToyAdapter` instantiates the right `.tscn` and connects signals.
- Composition: `KEY_PHYSICS_TOY` in `main.gd._build_default_ports`.
- Template JSON `objects[]` gains optional `physics_kind: "ball"|"crate"|"trampoline"|...` — `world_renderer` dispatches to PhysicsToyPort.

**Safety failsafe**: every physics body has `max_contacts_reported = 0` unless a script needs them (perf). Per-body `linear_damp_mode = REPLACE` with damp 0.5 prevents runaway velocities that could clip the kid out of the world.

**Perf budget**: Jolt handles ~500 active rigid bodies on M2 Max at 60 fps comfortably. Worlds will have ≤40 active toys. Inactive (sleeping) bodies cost ~zero.

### Wave 0 — prerequisites (½ day, 1 worker)
Single commit. Unblocks everything else.

1. Tune glTF importer defaults in project.godot: `meshes/generate_lods=false`, `meshes/light_baking="Disabled"`, `meshes/create_shadow_meshes=false`, `materials/location="Built-In"`.
2. Confirm `rendering/shader_compiler/shader_cache/enabled=true`.
3. Add `OS.has_feature("macos")` gate skeleton in `gameplay_runtime.gd` so MetalFX setting can be applied conditionally in Wave 1.
4. Install Terrain3D GDExtension to `addons/terrain_3d/` (no scene changes yet).
5. **Switch 3D physics engine to Jolt** — `physics/3d/physics_engine = "Jolt Physics"` in project.godot. Re-run smoke test to confirm CharacterBody3D + GroundPlane interactions still pass.
6. Wipe `.godot/imported/` after settings change and let run.sh rebuild.

**Exit**: full reimport completes in <15s on M2 Max (down from ~30s).

### Wave 1 — highest-ROI parallel triple (3 days, 3 workers)
Three independent units; ship in parallel via `/batch` worktrees.

#### W1.A — Graphics polish pass (1 day)
File: `src/adapters/inbound/gameplay/gameplay_runtime.tscn` + `shaders/toon_cel.gdshader`.
- Replace `ProceduralSkyMaterial` with `PhysicalSkyMaterial` (settings per graphics doc §2).
- Add Volumetric Fog at density 0.015, length 96m, GI Inject 0.6, anisotropy 0.3.
- Enable MetalFX Temporal upscaling at 0.67 scale + 0.3 sharpness, guarded by `OS.has_feature("macos")`.
- PSSM tune: `shadow_normal_bias 2.0`, `shadow_blur 1.0`, `shadow_opacity 0.85`.
- Tonemap → ACES + warm-morning LUT (32³ PNG, contribution 0.6).
- Patch `toon_cel.gdshader`: drop `specular_disabled`, add banded smoothstep, sky-tinted rim, stylized specular blob.

**Exit**: smoke test passes; M2 Max frame budget delta ≤ +0.5 ms (net positive from MetalFX); visual diff screenshot shows sky+fog+rim improvement on `local_kid_1_starter_adventure`.

#### W1.B — Environment + assets (1-2 days)
Files: `data/` and new `terrain/` scenes per world.
- Enable Terrain3D plugin in Project Settings → Plugins.
- Replace flat GroundPlane in `gameplay_runtime.tscn` with Terrain3D region per starter world (heightmap from Poly Haven CC0 or hand-painted at low res).
- Drop 3 × 1K Poly Haven HDRIs (kloofendal-like cartoon morning, soft sunset, mossy forest dawn) into `data/textures/hdri/` and bind one per world in `world_renderer.gd`.
- Pull 4 ambientCG materials per world (grass/dirt/sand/stone for Wyspa; grass/dirt/wood-floor/path for Farma; moss/dirt/leaf-litter/mushroom-cap for Las).
- Wire Terrain3D foliage instancer with Kenney grass blade meshes — chunked 32m cells.
- (Stretch) Run Materialize on 6 Kenney atlases to generate normal+roughness+AO; inject into glTF JSON via existing Python pipeline.

**Exit**: each starter world has a Terrain3D ground with painted splat material + matching HDRI ambient; no more 80×80m flat box; smoke test still passes.

#### W1.C — Mechanics: camera + AnimationTree + rules engine (3 days, sequential within unit)
Files: `src/adapters/inbound/gameplay/player_controller.{gd,tscn}`, new `compiled_rule.gd`, `rule_compiler_service.gd`, `godot_rules_runtime_adapter.gd`, `quest_hud.tscn`.

**1C-1 — SpringArm3D + camera tilt-on-jump (½ day)**
- Refactor scene: add `CameraPivot` (Node3D, top_level) + `SpringArm3D` (length 4.0, sphere shape r=0.3, exclude player layer) + `Camera3D` at arm tip.
- Move yaw rotation from CharacterBody3D to CameraPivot. Character mesh rotates to face velocity direction.
- Tilt-on-jump: `CameraPivot.rotation.z = lerp(0, 0.08, clamp(velocity.y/6, 0, 1))`.
- Set up "world" + "player" physics layers; exclude player from spring arm mask.

**1C-2 — AnimationTree (1 day)**
- Author `player_anim_tree.tres` (StateMachine root, Locomotion BlendSpace1D, JumpStart/Loop/Land states).
- Delete `_play_anim` + `LOOPING_ANIMS` const + loop-mode override hack.
- Wire conditions: `is_on_floor`, `is_jumping`, `is_falling`. `blend_position = horiz_speed / SPRINT_SPEED`.
- Hard-landing variant on `velocity.y < -5`.

**1C-3 — Rules engine + quest HUD (1.5 days)**
- `CompiledRule` (RefCounted, no Godot types) with Trigger/Action enums per mechanics doc §4.
- `RuleCompilerService`: regex parse `compiled_logic` strings into CompiledRule list. Cover the 6 patterns in `data/templates/*.json`.
- `RulesRuntimePort` + `GodotRulesRuntimeAdapter` (Node, ticked from `GameplayRuntime._physics_process`).
- `quest_hud.tscn`: HBox with item icon + 5 pip TextureRects + flag icon. Listens to `rules_event` signal.
- Persistence rides existing `SessionProgressStorePort` debounced 250ms flush.
- Wire `KEY_RULES_RUNTIME` in `main.gd._build_default_ports`.

**Exit**: kid camera no longer rotates character mesh; idle→walk→sprint cross-fades; harvest-5-carrots quest end-to-end on Mała farma (pips fill, fanfare, sell_zone unlocks).

### Wave 2 — second-tier polish (3-4 days, parallel where possible)

| Unit | What | Cost | Depends on |
|---|---|---|---|
| W2.A | Hover + double-jump + soft-respawn (fall-y-<-10) | S, ½ day | W1.C-1, W1.C-2 |
| W2.B | Triplanar ground shader (grass/dirt by world-Y) — if not using Terrain3D for a world | S, ½ day | W1.A |
| W2.C | Vertex wind on Kenney trees + grass-blade flutter | M, 1 day | W1.A (shader pipeline) |
| W2.D | Character decal shadow blob (Decal node + radial gradient PNG, projected DOWN) | S, ¼ day | none |
| W2.E | Quaternius Universal Animation Library import + BoneMap retarget + extra anims (climb/swim/wave/sit/dance) | M, 1 day | W1.C-2 |
| W2.F | Sub-emitter particle upgrade (pickup-sparkle trails, water-splash mist, falling-leaves ambient, dash trail) | S-M, 1 day | none |
| W2.G | Interactable3D base + 6 subclasses (Pickup, Checkpoint, Door, Button, Breakable, WaterZone) | M, 2 days | none |
| W2.H | NavigationRegion3D bake-at-world-load + bunny companion FSM (½ day) + butterfly idle helper (½ day) | M, 1 day | none |
| W2.I | UISfxPlayer autoload + AudioStreamSynchronized music layers per world + VoiceExclamation (Polish) | M, 1.5 days | none |
| W2.J | Stylized toon water shader on Wyspa skarbów coast + Mała farma pond | S, ½ day | W2.G (WaterZone) |
| W2.K | Physics toy adapter + 4 starter toys (ball, crate, trampoline, see-saw) + JSON template wiring | M, 1.5 days | Wave 0 (Jolt swap) |
| W2.L | Buoyancy Area3D in WaterZone + ragdoll bunny on knockdown (PhysicalBoneSimulator3D) | S-M, 1 day | W2.G + W2.H |

W2.A through W2.D edit shaders/effects, no shared files. W2.E-W2.J each touch isolated nodes. Run 4-5 in parallel.

**Exit Wave 2**: all 3 starter worlds have at least 2 working quests, hover+double-jump make platforming forgiving, NPCs follow + hint, music swells on quest-active, water+wind sell the "living world" feel.

### Wave 3 — deferred / nice-to-have (cumulative ~3-4 days, low priority)

| Unit | Why deferred |
|---|---|
| LightmapGI bake on static ground+props | Only valuable once visible-prop set is locked; current procedural worlds make bake throwaway |
| LimboAI behavior trees for villager NPCs | Tier 1 FSMs cover the 3 starter NPCs; install LimboAI only when >3 NPC types with branching idle behaviors |
| Subtle camera DoF + vignette + bloom polish | Tonemap+LUT in Wave 1 already covers 80% of the visual delta |
| Mantle / ladder / slide controller moves | Adult mechanics; out of age 5-8 motor scope |
| AudioStreamInteractive (Wwise-style state-music) | AudioStreamSynchronized in Wave 2 gets us 70% there for free |
| Inverted-hull or Sobel-screen outlines | Toon shader hybrid in Wave 1 reads cleanly without outlines |
| True Ollama token streaming (carry-over from Wave C) | Option B "honest non-streaming" still chosen |
| Per-prop Materialize PBR maps for non-hero props | Wave 1 covers hero atlases; the other ~700 Kenney props don't need it |
| SoftBody3D cloth (capes, flags, jelly enemies) | Requires Godot Physics fallback — re-evaluate after Jolt stabilizes; not critical for kid feel |
| VehicleBody3D for kid karts | Cute but scope creep; only if a "racing" starter world is greenlit |
| Per-bone ragdoll on the kid character itself | Comedy beat in some games but kid-disturbing if it triggers on fall-respawn; safer to keep player as CharacterBody3D always |

---

## Don't-do list (consolidated)

- SDFGI / VoxelGI (4.6 regression, Apple Silicon cost, SDFGI deprecation pending).
- TAA (superseded by MetalFX Temporal).
- MSAA 8x (incompatible with MetalFX, too expensive at Retina).
- SSR (matte Kenney props gain nothing).
- FSR2 on macOS (MetalFX is 16-19% faster on Apple Silicon).
- Pure PBR conversion of all Kenney props (no normal/roughness/metallic source maps; offers zero upgrade).
- Per-mesh inverted-hull outlines (doubles draw calls).
- Custom hair / SSS / subsurface shaders (not in art direction).
- StaticBody3D per grass tile / GPUParticles3D for static foliage (per-node overhead + sim cost).
- Substance Sampler (paid Adobe; Materialize covers what's needed).
- LimboAI for game-world rules (overkill; Resource-driven dispatch is 13 lines of `match`).
- Combat NPCs / damage HP / game-over screens (violates kid-safe constraint).

---

## Dependency map

```
Wave 0 (import defaults + Terrain3D install + MetalFX gate skeleton)
    │
    ├──> W1.A (graphics)        ──┐
    ├──> W1.B (assets)          ──┤
    └──> W1.C-1 (camera) ──> 1C-2 (anim tree) ──> 1C-3 (rules)
                                 │
                                 ├──> W2.A (hover/2x jump/respawn)
                                 └──> W2.E (Quaternius library)
        W1.A ────────────────────┴──> W2.B/C (triplanar + wind shaders)

    Independent of Wave 1:
        W2.D shadow decal
        W2.F sub-emitter particles
        W2.G interactable3D + subclasses
        W2.H navigation + companions
        W2.I audio layers + Polish exclamations
        W2.J toon water (needs W2.G WaterZone)
```

---

## Estimated dev cost

| Wave | Calendar days (1 dev) | Parallel days (3 devs / batch) |
|---|---|---|
| Wave 0 | 0.5 | 0.5 |
| Wave 1 | 5-6 | 3 (parallel W1.A/B/C) |
| Wave 2 | 8-10 | 3-4 (parallel batches of 4-5) |
| Wave 3 | 3-4 | 2 (parallel) |
| **Total** | **17-21 days** | **8-10 days with /batch** |

A solo developer ships AAA-feel in ~3 working weeks. With `/batch` worktree parallelism, ~2 weeks.

---

## Cross-axis "Next 3 features" alignment

Each agent ranked their top 3 first-features. Synthesis:

| Agent | #1 | #2 | #3 |
|---|---|---|---|
| Graphics | MetalFX + PhysicalSky + Volumetric Fog | PSSM tune + toon shader hybrid | Tonemap+LUT |
| Assets | Stylized sky + HDRI IBL | Toon water shader | Terrain3D splat texturing |
| Mechanics | SpringArm3D + tilt-on-jump | AnimationTree + BlendSpace | Rules engine + quest HUD |
| Physics | Jolt engine swap (Wave 0) | Kickable ball + breakable crate (W2.K) | Trampoline + see-saw joints (W2.K) |

All three #1 picks land in **W1.A** (graphics polish) + **W1.B** (env assets) + **W1.C-1** (camera). Wave 1 is the literal intersection of all three agents' top priorities.

---

## Hexagonal-architecture impact

New ports introduced (all outbound, all in `src/ports/outbound/`):
- `RulesRuntimePort` (mechanics §4)
- `NavigationPort` (mechanics §6, wraps experimental NavigationAgent3D)
- `NpcAgentPort` (mechanics §6)
- `MusicDirectorPort` (mechanics §9, wraps AudioStreamSynchronized/Interactive)
- `PhysicsToyPort` (physics §, wraps RigidBody3D `.tscn` instancing + impulse application)

New adapters (all in `src/adapters/inbound/gameplay/`):
- `GodotRulesRuntimeAdapter`
- `GodotNavigationAdapter`
- `BunnyAgentAdapter`, `ButterflyAgentAdapter`, (later) `LimboAIVillagerAdapter`
- `GodotAudioStreamInteractiveAdapter`
- `GodotPhysicsToyAdapter`

New domain types (all RefCounted, no Godot leakage):
- `CompiledRule` + `Trigger` + `Action` enums
- `NavTarget` value type
- `NpcMood`, `NpcRole` value types
- `MusicState` enum
- `PhysicsToyKind` enum, `PhysicsImpulse` value type

Composition root (`main.gd._build_default_ports`) gains 4 KEY_* entries. The existing Wave B `.github/workflows/composition-root-gate.yml` catches missing wires automatically. No CI infra changes needed.

---

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Godot 4.6 GI regression bites if we accidentally enable SDFGI/VoxelGI | low | high | hard rule in don't-do list; lint check in run.sh `--check` to grep for these |
| MetalFX falls back to bilinear on non-Apple-Silicon Mac and triggers TAA jitter (issue #103782) | medium | medium | gate with both `OS.has_feature("macos")` AND `RenderingServer.has_os_feature("metalfx")` |
| Terrain3D plugin breaks on Godot 4.6.2 update | low | medium | pin Terrain3D version in `addons/`; smoke-test in CI |
| player_controller refactor breaks existing CHOYCE_AUTOPLAY smoke test | medium | high | run.sh `--smoke` is mandatory pre-commit hook; spring-arm wiring keeps `spawn_at` API stable |
| AnimationTree migration loses the loop-mode hack and break Kenney clips | medium | medium | AnimationTree forces loop on Locomotion node natively; verify Kenney `idle`/`walk`/`sprint` clip names match BlendSpace points |
| Jolt physics swap subtly changes collision shape behavior — kid tunnels through GroundPlane | low | high | smoke test `--smoke` covers fall-through; pre-flight: confirm CharacterBody3D + StaticBody3D + Area3D pass; Jolt's docs list 4 minor API divergences, none affect current code |
| RigidBody3D toys go to sleep on world load and never wake | medium | low | every toy `.tscn` sets `sleeping = false, can_sleep = true`; sleep is desirable when player isn't nearby — saves perf |
| PhysicalBoneSimulator3D ragdoll bunny gets stuck in geometry on stop | medium | medium | re-anchor with `physical_bones_stop_simulation()` + tween back to companion follow position over 0.4s; never lock bones mid-collision |
| Rules engine regex compiler chokes on unrecognized `compiled_logic` syntax | high | low | unrecognized rules log warning + skip, never crash; add per-template smoke test |
| LimboAI install breaks GDExtension on macOS arm64 | medium | low | LimboAI is deferred to Wave 3; can ship without it |

---

## Punchlist — actionable next 3 commits

1. **Wave 0 prerequisites**: tune project.godot import defaults, install Terrain3D to `addons/`, add MetalFX `OS.has_feature` gate skeleton to `gameplay_runtime.gd`. ½ day, single commit.
2. **W1.A graphics polish**: Environment_basic → PhysicalSky + Volumetric Fog + MetalFX + PSSM tune; `toon_cel.gdshader` evolution per graphics doc §3. 1 day, 1 commit. Smoke test must pass.
3. **W1.C-1 SpringArm3D camera**: refactor `player_controller.tscn` + `.gd` to move yaw to CameraPivot, add SpringArm3D with proper layer mask, add tilt-on-jump. ½ day, 1 commit. Manual playtest required (no automated camera-feel test exists).

After these 3, **W1.B (Terrain3D)** and **W1.C-2 (AnimationTree)** unblock; ship them in parallel via `/batch`.

---

## References

All citations consolidated from the 3 source docs:
- `thoughts/shared/research/godot-graphics-aaa-2026-05-19.md` (graphics — 30+ Godot doc / PR / issue / community refs)
- `thoughts/shared/research/godot-assets-aaa-2026-05-19.md` (assets — Materialize, Quaternius, MixaBridge, Terrain3D, Poly Haven, ambientCG)
- `thoughts/shared/research/godot-mechanics-aaa-2026-05-19.md` (mechanics — SpringArm3D, AnimationTree, LimboAI, GPUParticles3D, AudioStreamInteractive)

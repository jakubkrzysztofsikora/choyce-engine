# Immediate Graphics and Mechanics Actions

## Scope

This report ranks the ten actions most likely to make the Choyce sandbox look
and feel playable immediately. It is based on the current Godot 4.6 Forward+
project, the supplied gameplay screenshot, the current repository wiring, and
current upstream documentation and repositories checked on 2026-09-09.

The ranking optimizes for visible improvement per implementation day, low
regression risk, child-safe gameplay, and compatibility with the existing
hexagonal boundaries. The project already contains Terrain3D, Kenney and
Quaternius assets, a working feedback harness, dialogue/combat/crafting domain
services, and a large `WorldRenderer`; the fastest path is to finish and unify
those paths rather than add a new engine or rewrite the game.

## Diagnosis

The current screenshot is not primarily an asset-download problem. It shows a
partially authored scene with four presentation failures:

1. Terrain and dressing are not guaranteed to share one ready height source.
2. The close camera makes flat materials, weak contact shadows, and sparse
   composition obvious.
3. Character presentation is still a basic mesh/animation path rather than a
   blended locomotion state machine.
4. Existing mechanics are present in code but are not yet presented as a
   readable player loop with strong feedback, NPC behavior, and interaction
   affordances.

The startup warnings confirm two integration bugs:

- `OnboardingOverlay` reports that TTS is unavailable because
  `CreateShell.setup()` is called from `src/adapters/inbound/main.gd` without
  its optional `voice_prompt` argument. This is a real missing dependency
  injection, although it should not block offline play.
- `WorldRenderer._terrain_grounded_position()` is called before the vendored
  Terrain3D data is ready. The current fallback preserves authored Y values;
  it is safe for startup but visually unsafe for props on terrain relief.

## Top ten actions

### 1. Make Terrain3D readiness authoritative for placement and collision

**Impact: highest visual correctness; effort: 0.5-1.5 days.**

Add an explicit Terrain3D readiness signal/state to
`Terrain3DWorldAdapter`. Queue terrain-dependent dressing until import and
height sampling are ready, then place every house, tree, NPC, resource node,
pickup, and collision proxy through the same `sample_height()` function.
Retain the hidden safety floor only as a physics fallback, never as a second
visual ground source.

Acceptance checks:

- no `terrain height sampling unavailable` warning during a normal launch;
- no visible prop has a foot/base gap larger than a small authored offset;
- player, navmesh, interaction ray, and visual terrain agree at five probe
  points;
- the GPU audit captures a grounded close camera, not only a headless pass.

This is the first fix because better models still look broken when their Y
coordinates are wrong.

### 2. Replace the flat opening composition with one deliberate camera frame

**Impact: very high; effort: 0.5-1 day.**

Use Godot's native `SpringArm3D` third-person rig: a camera pivot owns yaw and
pitch, a sphere-shaped spring arm handles obstruction, and the player body
rotates toward movement independently. Set a close shoulder distance, a
bounded pitch, camera follow damping, and a collision mask that excludes the
player. Keep mouse capture and ESC as a capture toggle; an explicit UI button
ends the session.

The 4.6 SpringArm tutorial is the authoritative implementation reference. This
will immediately improve framing, wall clipping, look-around, and the feeling
of physical space without importing a camera plugin.

### 3. Establish a real authored environment pass

**Impact: very high; effort: 1-2 days.**

Extract the existing `WorldRenderer` authored terrain/material/dressing path
into a shared presentation adapter. `SandboxLevel` should contribute only
kit-specific gameplay anchors: build pad, resources, NPCs, training target,
house, reward, and pond. Remove duplicate raw-fragment assembly from the
sandbox opening path.

The opening needs one visual language:

- a sky and sun direction with intentional warm/cool contrast;
- textured terrain with visible albedo variation and roughness;
- a readable path and clearing hierarchy;
- a few large hero props plus clustered secondary dressing;
- contact shadows at house, player, trees, and pickups.

Do not solve this with more fog. Fog should support depth, not hide missing
ground.

### 4. Use a controlled Environment/post-processing profile

**Impact: high; effort: 0.5 day.**

Create a sandbox-specific `WorldEnvironment` profile with a procedural or
HDRI sky, calibrated exposure/tonemap, moderate SSAO, restrained glow, and
volumetric fog disabled at play scale. Add a distance fade or very light
atmospheric haze only after the near-ground frame is correct.

Godot's Environment system provides sky, tonemapping, SSAO, glow, fog, and
adjustment controls natively. The project already disables fog in parts of the
sandbox, but the profile should be centralized so graphics tiers cannot
silently re-enable a washed-out setup.

### 5. Upgrade characters through a real AnimationTree locomotion graph

**Impact: high; effort: 1-2 days.**

Keep the existing Kenney/Quaternius-compatible model pipeline, but stop
selecting clips with ad-hoc string calls. Build an `AnimationTree` with:

- `BlendSpace1D`: idle, walk, sprint;
- jump start, fall, and land states;
- cross-fade transitions;
- speed-driven blend position;
- an explicit talking state that drives facial/mouth performance.

Godot's AnimationTree is built for blending and state-machine transitions, so
this is a native module, not a dependency risk. It directly addresses the
floating, static-looking characters in the screenshot.

For replacement models, prefer the already-shipped Kenney Mini Characters for
the first pass. Quaternius is a useful second source for a visually coherent
character/animal set under its current QAL terms, but adding a new skeleton
family before the animation contract is stable would increase integration risk.

### 6. Make terrain, props, and foliage materially coherent

**Impact: high; effort: 1-3 days.**

Use Terrain3D's material blending for the large ground surface and add a small
curated set of CC0 texture/material inputs from Poly Haven where the current
terrain layers are visibly flat. Use Terrain3D instancing or Godot
`MultiMeshInstance3D` for repeated grass, flowers, rocks, and small trees.

Recommended visual budget for the opening clearing:

- 2-3 terrain layers: grass, dirt path, rock/shore;
- 3 foliage silhouettes at different scales;
- 2 rock/ground clutter families;
- 1-2 hero landmarks, not dozens of disconnected fragments;
- a warm local accent around the house and reward.

Poly Haven publishes CC0 assets; Kenney assets in this repository are already
catalogued as CC0. Preserve attribution/license records for any new source.

### 7. Add immediate game-feel feedback to every interaction

**Impact: high; effort: 0.5-1.5 days.**

Use native `GPUParticles3D`, short audio cues, hit flashes, camera impulse,
floating numbers/icons, and a small HUD state change for:

- gather wood/stone;
- craft;
- hit and defeat a training target;
- repair the house;
- claim the reward;
- place/remove a build block;
- talk and receive a quest step.

The repository already has effect/audio adapters and evidence capture. The
missing piece is consistent presentation at the action boundary. Every action
should produce a visible confirmation within 200 ms and an audible/captioned
confirmation when audio is unavailable.

### 8. Turn the opening into a readable quest loop

**Impact: high mechanics value; effort: 1-2 days.**

Expose the existing gathering, crafting, combat, repair, dialogue, and reward
systems as a single five-step objective ribbon with large icons and progress:

`zbierz -> zrób -> poćwicz -> napraw -> odbierz`.

The domain services and test bridge already cover much of this behavior. Add a
thin presentation adapter that listens to domain events, updates the HUD,
marks the next nearby interaction, and persists the current step. Do not build
a second quest engine or put rules in UI code.

### 9. Add one real companion/NPC behavior module

**Impact: medium-high; effort: 1-2 days.**

First use the native `NavigationAgent3D` already present for a deterministic
guide companion: idle, follow, point-to-objective, talk, and return-to-home.
Only add LimboAI after this behavior needs branching stateful behavior. LimboAI
is a credible MIT-licensed Godot 4 behavior-tree/state-machine module, but it
should own NPC behavior, not global rules, saves, or child-safety policy.

The companion must visibly walk, stop on the navmesh, face the child while
talking, and point toward the next objective. That creates more perceived game
quality than adding another passive model.

### 10. Wire voice as an optional, observable adapter

**Impact: medium; effort: 0.25-1 day.**

Pass the existing `TailnetVoiceAdapter` or `ElevenLabsVoicePromptAdapter` into
`CreateShell.setup()` and `PlayShell.setup_voice_prompt()` when configured.
When unavailable, suppress the repeated warning after the first diagnostic and
keep captions/audio cues working. Add a runtime status label for `voice on`,
`captions only`, or `offline`.

This is not the first graphics fix, but the current warning proves the adapter
boundary is incomplete. It also explains why characters “stopped talking”:
the UI path does not receive the port even though voice adapters and tests
exist.

## Ready modules worth using now

| Module | Use now | Reason | Boundary |
|---|---|---|---|
| Godot `SpringArm3D` | Yes | Camera collision and stable third-person framing | inbound gameplay adapter |
| Godot `AnimationTree` | Yes | Locomotion blending and talking/jump states | inbound player adapter |
| Godot `GPUParticles3D` | Yes | Cheap action feedback and polish | presentation adapter |
| Godot `NavigationAgent3D` | Yes | Companion and objective movement | inbound gameplay adapter |
| Vendored Terrain3D | Yes, after readiness fix | Continuous terrain, material blending, collision | outbound/render adapter |
| Terrain3D instancer or `MultiMeshInstance3D` | Yes | Foliage density without node explosion | presentation adapter |
| Kenney Mini Characters | Yes | Already present, CC0, low integration cost | asset catalog |
| Quaternius QAL packs | Selectively | Coherent extra characters/animals/props | asset catalog + notices |
| Poly Haven CC0 materials/HDRIs | Selectively | Ground detail and lighting inputs | asset catalog + notices |
| LimboAI | Later in this slice | Useful for richer NPC BTs, not needed for core rules | NPC adapter only |

Avoid adding a second terrain engine, a general-purpose inventory plugin, or a
large AI scene-generation plugin. The project already has those domain seams;
the current problem is incomplete presentation wiring and readiness, not a
lack of frameworks.

## Execution order

### First feedback cycle

1. Fix Terrain3D readiness and placement probes.
2. Wire TTS ports and add an offline/captions-only status.
3. Install the SpringArm camera rig.
4. Capture wide and play-scale GPU frames.

### Second feedback cycle

1. Centralize the sandbox environment profile.
2. Replace flat terrain layers and add clustered foliage.
3. Convert player animation to AnimationTree.
4. Add interaction VFX/audio/HUD confirmations.

### Third feedback cycle

1. Add the objective ribbon and event-driven progression.
2. Add the deterministic companion behavior.
3. Evaluate LimboAI only if the native companion state machine becomes
   genuinely difficult to maintain.
4. Run the complete live input and render audit before accepting visual changes.

## Non-negotiable acceptance gates

- no unexplained startup warnings on the normal sandbox route;
- no floating player, NPC, house, resource, or pickup in the play-scale frame;
- textured ground remains readable without fog;
- mouse look changes the camera transform in the real window;
- ESC releases mouse capture without ending the session;
- idle, walk, sprint, jump, land, and talk visibly differ;
- every opening objective has a visible state and a reversible save;
- the complete opening loop remains green in the existing GPU feedback harness.

## Sources

1. Godot Engine, “Environment and post-processing,” stable documentation:
   https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html
2. Godot Engine, “Third-person camera with SpringArm,” Godot 4.6 documentation:
   https://docs.godotengine.org/en/4.6/tutorials/3d/spring_arm.html
3. Godot Engine, “Using AnimationTree,” stable documentation:
   https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html
4. Godot Engine, “3D navigation overview” and “Using NavigationAgents,” stable documentation:
   https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_introduction_3d.html
   https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html
5. Godot Engine, “3D particle systems” and `GPUParticles3D`, stable documentation:
   https://docs.godotengine.org/en/stable/tutorials/3d/particles/index.html
6. TokisanGames, “Terrain3D,” GitHub repository, MIT licensed, current repository:
   https://github.com/TokisanGames/Terrain3D
7. limbonaut, “LimboAI - Behavior Trees and State Machines for Godot 4,” GitHub repository, MIT licensed:
   https://github.com/limbonaut/limboai
8. Kenney, “Assets,” official asset catalog:
   https://kenney.nl/assets
9. Poly Haven, “License,” official CC0 license page:
   https://polyhaven.com/license
10. Quaternius, “Quaternius Asset License (QAL),” official license page, updated 2026-08-28:
    https://quaternius.com/license.html
11. hi-godot, “Godot AI,” GitHub repository, MIT licensed:
    https://github.com/hi-godot/godot-ai
12. yurineko73, “Godot MCP Native,” GitHub repository, MIT licensed:
    https://github.com/yurineko73/Godot-MCP-Native

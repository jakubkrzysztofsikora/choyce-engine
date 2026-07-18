# Choyce Engine — Vertical Slice Delivery Plan

Updated: 2026-07-17

## Objective

Deliver a family-friendly, styled, replayable 3D Adventure sandbox slice that a child can launch, understand, freely explore, discover, interact with, and leave safely. Optional combat and activities should enrich the world without turning the first experience into a checklist. Then promote the same runtime into a packaged engine/product slice with one reversible creation interaction and governed AI assistance.

The current branch is a functional technical prototype, not yet a convincing game. Automated tests are broadly healthy, but the rendered result still reads as a debug scene: flat/saturated materials, sparse authored content, weak spatial composition, oversized or developer-like HUD elements, and a cinematic/audio pass that needs another quality bar. The visual rescue below is now a release gate, not optional polish.

### Latest implementation evidence — VS-019 (2026-07-17)

- The runtime floor and Adventure template now cover `2400m × 2400m`
  (`5.76km²`), with a 5×5 player-relative chunk envelope and deterministic
  seed/version/coordinate chunk identity.
- A physical four-sided coast now blocks the final 52m before the ground edge;
  the old "run for 20 seconds into the void" failure has a regression test.
- Live render exposed imported-character scale drift, which was calibrated to
  the child-sized collision reference. This is not a visual-rescue pass: the
  opening composition and terrain materials still fail the presentability gate.
- Evidence: `test_world_renderer_toon_shader.gd`,
  `template_loader_starter_smoke.gd`, editor parse, and smoke boot passed.
- Independent adversarial review: **FIX-FIRST**. Before VS-019 can close, it
  needs budgeted (non-blocking) chunk construction, a visible colliding coast
  rather than only an invisible safety wall, deterministic reload/physics
  coverage, coherent river/bridge traversal, and retained clean-profile
  boundary/performance captures. The invalid `Koral` placeholder and outer
  chunk spill were corrected after that review; the remaining items stay open.
- Follow-up in progress: generation now runs in the renderer under a 3.5ms /
  three-cell frame budget after movement only schedules chunks. The outer void
  is replaced with an ocean sheet and a deterministic, toon-muted cliff belt
  with collision inside the visual geometry. A second adversarial review kept
  VS-019 **FIX-FIRST**: it prompted disposal budgeting and segmented,
  cliff-aligned collision (both now implemented). It still needs long-run
  boundary and frame-time capture on the reference machines, plus deterministic
  completed-job/reload and physical-player regression evidence, before closure.
- Sandbox-loop follow-up: forest logs and cave ore caches are now explicit,
  one-use world interactions. They feed the existing three-wood stick and
  wood/iron sword ladder, update the pictorial inventory, and give the child a
  concrete gather → upgrade → build/cook loop without a timer. The river now
  blocks direct crossing except at the authored bridge.
- Opening-frame follow-up in progress: the gameplay camera is now pitched down
  toward the route rather than the sky, and the CC0 AmbientCG Ground003
  colour/normal/roughness maps are wired into the 2.4km terrain material. A
  new authored forest mass extends roughly 400m × 300m north-west from its
  signposted entrance, with a clear trail, irregular clearings, and
  scale-matched tree collision. This is a direct response to the "out of the
  map in 20 seconds" and tiny-prop reports; it still requires clean-profile
  play capture and visual review before the rescue gate can pass.
- Opening combat follow-up: the three prototype enemies no longer spawn around
  the player. Optional encounters now wait at the cave, deep forest, and
  beach, preserving the intended non-combat first minute while the remaining
  creature-art replacement work stays inside the visual-rescue gate.
- Opening-material follow-up: the template terrain duplicated the scene-owned
  PBR ground 25cm above it, hiding the river, trail, and ground dressing.
  Adventure now uses one floor only. A focused visual review then required the
  route to end at each riverbank and the bridge to read as its own crossing;
  those corrections and a Kenney-only foreground foliage pass are in progress.

## Scope decision

### Gate A — Adventure playable slice

Critical path:

`launch → click Adventure → meet guide → wander and discover → interact → optionally fight/build → return or keep exploring → replay`

Required:

- Data-driven Adventure world with a sandbox/free-play session contract; no compulsory target, score, timer, or victory screen.
- A substantial exploration island (target 2400×2400m traversable floor —
  5.76km² — with deterministic streamed procedural biomes) with
  four readable landmark regions, natural traversal routes, and no visible
  hard map edge from the opening area.
- Flora, fauna, ambient motion, landmark labels/signposts, and encounter zones
  distributed across the island rather than a spawn-room arena.
- Kid-safe first-run combat policy.
- Friendly NPC with captions and optional governed voice.
- Optional combat, reward feedback, soft respawn, and clean session teardown.
- A friendly opening guide, readable landmarks, discoverable NPCs, animals,
  flora, houses, forest, beach, cave, and ambient world motion.
- No runtime scene-tree errors.
- Clean-profile manual evidence on Tier 1 and Tier 2 hardware.

Not required to pass Gate A:

- Ollama world creation.
- Real microphone/STT.
- Obby, multiplayer, publishing, or cloud services.

### Gate B — Engine/product slice

Required after Gate A:

- Tauri package launches and supervises the Godot sidecar.
- One small creator loop: collect → upgrade → place decoration → undo/replay.
- AI assistance uses input/output moderation, parent approval for high-impact changes, audit events, and reversible mutations.
- Accessibility, localization, performance, audio, and visual evidence are captured rather than inferred from headless tests.

## Current release blockers

1. VS-001, VS-002, and VS-003 are implemented but still need cross-agent review and retained evidence.
2. The clean-profile Adventure sandbox journey has not been manually proven.
3. Manual evidence for TASK-055, TASK-056, TASK-059, and TASK-060 is missing.
4. Tauri remains a smoke-command skeleton and cannot launch Godot.
5. Voice input remains canned/placeholder and AI tool execution still uses a synchronous shim.
6. The worktree contains unreviewed renderer/config changes and generated/imported assets.

## Visual rescue gate — required before calling the demo presentable

The next playable demo must look intentional in the first screenshot and remain
interesting for the first five minutes. Functionality alone is not evidence of a
vertical slice. Every item below needs a rendered/manual check in addition to
headless tests.

### World and composition

- Replace the empty opening square with a composed starting grove: trail, guide,
  readable landmark, house/yard, vegetation clusters, ambient animals, and at
  least two visible routes onward.
- Hide the world boundary from the opening camera with terrain continuation,
  foliage, hills, water, fog, or authored background geometry. No visible
  rectangular island edge or eternal chasm.
- Make the island feel large through layered sightlines and destination reveals:
  village, forest, beach, cave, and one distant landmark must each have a
  recognizable silhouette and a reason to walk there.
- Use procedural generation only for repeatable dressing and macro variation;
  the opening route and landmark beats remain curated so the child is never
  dropped into an empty random field.
- Procedural macro cells must extend well beyond the opening view so sprinting
  for 20 seconds does not reach a hard edge or an empty test void. The seed is
  deterministic per world id and remains safe to regenerate.
- Player-relative scale is explicit: the player rig is the 1.8m reference;
  houses, tree clusters and bridges are scaled as places rather than props.
- Traversable set pieces use collision boxes. The starter homestead includes an
  openable door, walkable interior, furniture, sit interaction and a forgiving
  cook-food/heal loop so the sandbox has a normal-life activity before combat.

### Materials, lighting, and asset language

- Establish one restrained palette and material language for ground, water,
  foliage, architecture, characters, and interactables. Remove neon rainbow
  defaults and untextured debug colors from the main camera.
- Add real surface variation to terrain and props: albedo detail, roughness
  differences, slope/shore transitions, foliage variation, and contact shadows.
- Prefer cohesive ready-made Kenney, Quaternius, KayKit, and existing project
  assets. Do not mix disconnected art packs in the same focal composition.
- Add a daylight setup with controlled exposure, ambient occlusion/contact
  grounding, soft shadows, atmospheric depth, and a consistent horizon.

### UI and onboarding

- Replace the oversized control legend, emoji/debug icon treatment, rainbow
  hotbar, giant world labels, and mascot overlay with a compact modern HUD.
- Keep only context-relevant information on screen: health/energy when needed,
  selected item, short interaction prompt, captions, and a small pause/help entry.
- Use iconography from one visual system, readable typography, translucent
  panels, consistent spacing, focus states, and controller/tablet-safe hit areas.
- The think-demo launcher starts without the old “Cześć, jestem twoim ninja”
  greeting. Trailer character voices are separate, youthful ElevenLabs voices,
  queued serially, captioned, and never allowed to overlap.

### Cinematic and sound bar

- Keep the 5–10 second trailer as a real 3D shot with clear front-facing
  silhouettes, readable anticipation/contact/recovery, intentional camera shots,
  restrained impacts, and the monster fully inside frame.
- Ziemek and Gniewko must have distinct, masculine youthful deliveries with
  emotional variation; every line must match its caption and finish before the
  launcher handoff.
- Physical attacks use physical ElevenLabs-generated punch/kick/whoosh assets;
  music stays below dialogue and important cues are audible on laptop speakers.

### Visual acceptance checks

- Capture rendered screenshots at launcher, 15 seconds into exploration, the
  first guide interaction, a region transition, and an optional combat moment.
- At launcher and spawn, no debug letters, clipped actors, visible map edge,
  flat placeholder terrain, or empty square composition may be present.
- A reviewer unfamiliar with the code can identify the player, guide, route,
  nearest landmark, interaction affordance, and destination from the images
  alone.
- Run the same checks at the project reference resolution and a laptop-sized
  window; no major label, HUD, or camera framing break is acceptable.

### Visual-rescue re-audit — 2026-07-18

The rendered opening remains a **technical prototype**, not a presentable demo.
An independent hostile visual review rejected the prior VS-012/VS-013 completion
claims from a live capture. The next implementation order is fixed by those
findings:

1. Replace the repeated two-tree horizon grid with composition-constrained,
   varied biome clusters that preserve verified source materials. The supplied
   Quaternius Medieval Village architecture is approved for the focal house;
   its FBX nature set is currently rejected at runtime because it renders black
   ground/underside artefacts under the existing material path.
2. Replace the sharp plane-overlay trails with terrain-native, feathered,
   terrain-conforming ground treatment; a darker rectangle over grass is not
   acceptable as a path.
3. Replace the primitive bridge ramps and straight translucent water strip with
   coherent bridge/embankment geometry, animated water material, varied banks,
   and a render review from both approaches.
4. Complete one material/lighting contract across terrain, foliage,
   architecture, animals, NPCs, interactables, and HUD. Native PBR materials
   remain preferred; category-specific replacements are allowed only for a
   demonstrated broken source asset.

The 2026-07-18 water/bridge review also returned `request_changes`: the water
surface is now animated and the old wedge is collision-only, but the exposed
primitive deck and disconnected stair meshes still read as blockout. Before
this route can pass, replace it with one material-preserving authored bridge
assembly, use bounded/low-frequency water deformation with banks/shallows, and
add a true player-collider traversal test across both ramps and the deck.

A subsequent fresh capture review again returned `request_changes`. Its
blocking finding is broader: the opening mixes photographic terrain, flat
low-poly vegetation, selectively preserved textured architecture, toy
characters, and marker-like props. It also identifies overlapping path planes,
rectangular river geometry, repeated horizon silhouettes, unclear object scale,
and persistent debug-like HUD chrome. The visual rescue gate therefore remains
blocked until one cohesive opening material/asset contract, terrain-authored
paths and banks, scale/grounding cleanup, and contextual image-first onboarding
are rendered and independently accepted.

Completed immediate remediation: overscaled food pickup collision was reduced
to a hand-sized proxy and moved out of the opening hero frame; the white chicken
source now has an explicit farm-animal material override. Terrain layer scale
and saturation were reduced after render inspection. These are cleanup steps,
not visual-gate acceptance evidence.

### Adversarial review status — 2026-07-17

- Two independent hostile reviews were run after the world-scale pass. Both
  returned `FIX-FIRST`: headless smoke proves boot only; rendered gate evidence,
  collision/interaction integration coverage, safe migration, and a convincing
  large-world composition are still required before calling this presentable.
- The implementation pass addressed the most immediate regressions: stale local
  starter data is migrated only when untouched, Adventure rules/quests are now
  free-play, the opening no longer seeds cube placeholder resources, imported
  nature assets are larger and denser, and the river continues well beyond the
  bridge. These changes do not waive the rendered acceptance gate.

## Delivery gates

### Gate 0 — Repository truth

- Reconcile `project.godot`, `shell/next-env.d.ts`, generated imports, raw assets, and Cargo lock.
- Update stale backlog statuses and remove historical blockers that are no longer true.
- Keep the Forward+/SDFGI rendering decision explicit and validated.

Exit: intentional worktree, parse-clean Godot project, and a reproducible validation command set.

### Gate 1 — Canonical authored runtime

- Preserve node properties, transforms, source blocks, rule properties, and active state in `TemplateLoader`.
- Normalize JSON vector/color values at the inbound renderer boundary without leaking Godot nodes into domain/application code.
- Copy trigger metadata into `Area3D` nodes and support `collectible`, `checkpoint`, `win`, and `win_zone`.
- Use one canonical template-to-runtime path for Adventure.
- Add tests from template JSON through runtime-facing entities.

Exit: authored Adventure and Obby trigger/property tests pass; no data is silently discarded.

### Gate 2 — Playable Adventure proof

- Confirm the NPC scene-tree lifecycle fix remains clean in rendered and
  clean-profile runs.
- Place the guide at the opening trail and distribute encounters across the
  island so the first minutes teach movement and discovery.
- Verify free-play startup, guide dialogue, exploration, region discovery,
  optional combat, soft respawn, cursor release, exit, and teardown.
- Verify session stats and persistence/read models are correct after leaving
  and replaying a sandbox session.
- Execute the clean-profile sandbox charter and capture logs/screenshots/video.

Exit: a child can complete the loop without adult rescue; no high-severity runtime errors remain.

### Gate 3 — Feel and accessibility

- Add enemy telegraph/wind-up, hit response, soft aim assist, weapon differentiation, and clear reward feedback.
- Route music/SFX/voice through explicit buses and validate levels and blocking cues.
- Add reduce-motion behavior, controller/tablet-friendly controls, readable dynamic hints, and captions.
- Prefer existing approved KayKit/Quaternius/Kenney assets, template packs,
  rule blocks, and sample scenes. Create new assets or logic only when a
  rendered/tested gap remains.

Exit: manual kid-flow review passes on Tier 1/Tier 2 hardware with traceable defects.

### Gate 4 — Packaged product

- Implement Tauri Godot sidecar spawn, readiness, shutdown, reconnect, protocol versioning, authentication, and bounded message handling.
- Run packaged-shell smoke test, not only Godot direct launch.

Exit: installed shell launches the same Adventure slice and recovers from engine restart.

### Gate 5 — Governed creation loop

- Add one small reversible build/upgrade/decorate interaction.
- Replace canned STT with local-first real input and explicit opt-in fallback.
- Replace synchronous AI tool shim with cancellable async execution.
- Enforce input moderation, output moderation, parent approval for high-impact changes, structured audit, and Preview → Apply → Undo.

Exit: AI failure, refusal, cancellation, and rollback are safe and observable.

### Gate 6 — Expansion

- Add Obby only after Adventure acceptance is complete.
- Reuse the canonical template/runtime contracts; do not fork `GameplayRuntime` by template.

## Evidence requirements

Release evidence must include:

- Contract, application, safety, persistence, and domain-isolation outputs.
- Clean-profile Adventure win, loss, retry, and second-run evidence.
- Rendered screenshots and performance measurements on Tier 1 and Tier 2 hardware.
- Localization, captions, contrast, reduce-motion, and control-mode results.
- Parent consent, audit, delete/export, unsafe-input, and publish-block results.
- Packaged Tauri launch evidence for Gate B.

Headless performance and fixture-backed KPI reports are useful regression signals, but do not substitute for rendered/manual evidence.

## Planned backlog tasks

The executable task records live in `.ai/tasks/backlog.yaml` and must follow `todo → in_progress → in_review → done`. No task is done without cross-agent review.

| Task | Focus | Owner | Cross-review | Depends on |
|---|---|---|---|---|
| VS-001 | Preserve template transforms/properties/rule metadata | codex | claude | Gate 0 |
| VS-002 | Propagate trigger metadata and runtime trigger semantics | codex | claude | VS-001 |
| VS-003 | Fix NPC scene-tree lifecycle and runtime error smoke | codex | claude | Gate 0 |
| VS-004 | Clean-profile Adventure sandbox charter and evidence | copilot | codex | VS-001, VS-002, VS-003 |
| VS-011 | Sandbox interaction, ecology, and discovery polish | codex | claude | VS-004 |
| VS-012 | Visual art direction reset: palette, materials, lighting, and cohesive asset kit | codex | claude | VS-004 |
| VS-013 | Opening composition and world density: grove, routes, landmarks, horizon occlusion | codex | claude | VS-012 |
| VS-014 | Modern HUD/onboarding replacement and removal of debug presentation | codex | claude | VS-012 |
| VS-015 | Trailer quality/audio pass: acting, masculine youthful voices, queue, captions, mix | codex | claude | VS-012 |
| VS-016 | Rendered visual acceptance captures and Tier 1/Tier 2 performance evidence | copilot | codex | VS-013, VS-014, VS-015 |
| VS-020 | Tool-gated harvesting loop: find/craft axe and pickaxe, then cut trees and mine stone | codex | claude | VS-018, VS-019 |
| VS-021 | Rare vehicle discovery/driving and a bounded bulldozer destruction sandbox | codex | claude | VS-020 |
| VS-022 | Player customization: skin, hair, face, top, pants and shoes | codex | claude | VS-014 |
| VS-023 | Child-safe original liminal-creature encounter set, replacing slime placeholders | codex | claude | VS-005, VS-012 |
| VS-034 | Optional G-key social gag: local effect/SFX plus bounded, character-aware NPC reactions | codex | claude | VS-024, VS-015 |
| VS-005 | Combat feel, feedback, and easy-mode pass | mistral | codex | VS-004 |
| VS-006 | Audio buses, visual QA, accessibility, and rendered performance | mistral | copilot | VS-004 |
| VS-007 | Tauri sidecar and authenticated bridge | copilot | codex | VS-004 |
| VS-008 | Reversible creator interaction | claude | codex | VS-004 |
| VS-009 | Real voice/AI pipeline and safety governance | codex | claude | VS-008 |
| VS-010 | Obby expansion using shared runtime contracts | mistral | codex | Gate 6 |

## New sandbox systems — implementation order (2026-07-18)

### Priority rule — visual-first vertical slice

For every remaining task, the priority order is: **finished-looking graphics →
believable physical meshes/collision → animation/camera/audio → mechanics that
make the scene playable → expansion systems**. A feature that adds a flat
placeholder, untextured primitive, oversized proxy collider, invisible wall, or
debug-looking UI is rejected even if its logic works. Ready-made CC0 models,
PBR materials, authored animation clips, and verified shaders take precedence
over bespoke procedural placeholders. Headless tests guard regressions; a
rendered camera capture is the actual acceptance evidence.

### Current UI remediation — 2026-07-18

VS-014 is reopened. The latest hostile capture still found a bright, persistent
top-left trio of controls and numbered hotbar to be editor-like UI competing
with the opening composition. The active pass replaces those first-frame
buttons with one compact menu for the two infrequent actions (appearance and
safe return), exposes undo only after a build edit, and requires an updated
16:9 rendered review. This is a focused cleanup, not evidence that the larger
HUD/onboarding, material, world-composition, bridge, or terrain gates are met.

### Optional social gag — VS-034

The G-key gag is intentionally a bounded, family-friendly sandbox beat rather
than a combat system: a short player reaction, local ElevenLabs SFX, small
world-space cloud, and nearby NPC responses based on character role. Reactions
are single harmless gestures only—laugh, recoil/disgust, or an angry air-swat—
with no damage, chase, reputation change, or persistent smell state. A single
caption/voice queue prevents characters from speaking over one another, and
the offline caption fallback remains usable without an API key. It stays in
review and may not add persistent HUD chrome or obscure normal exploration.

Hostile review returned **request changes**: the implementation must cap and
advance unavailable voice turns quickly, correlate callbacks to a specific
reaction request rather than only its text, keep the NPC root/feet planted
during an angry swat, place the cloud and speech bubble safely for the active
third-person camera and each character height, and prove the action cannot
damage or alter combat state. VS-034 remains in progress; these fixes are
secondary to the opening visual rescue unless they are needed for a safe demo.

The second correction pass replaces the incorrect four-character drop with an
immediate world-space line for every nearby NPC, while keeping the optional
ElevenLabs/caption channel serialized. Reactions are authored next to each
adventure NPC's dialogue data, rather than embedded as identity checks in the
runtime. A normal greeting now owns that same channel until it finishes (or its
bounded fallback expires), so a G-key reaction cannot overlap or cancel it.
Combat-disabled characters may not perform an angry swat; the pirate instead
recoils with a non-combat line. Focused coverage now includes five nearby NPCs,
the combat-disabled pirate, stale callbacks, fallback, and a reaction during a
held normal greeting. The independent adversarial follow-up shipped after
VS-041 added cancellation-safe voice transport and visible child affordances;
VS-034 remains secondary to the opening visual rescue.

### Live capture reassessment — 2026-07-18

The post-change gameplay capture (`/tmp/choyce-now/current-gameplay.png`) proves
the main scene boots and the persistent top-left control strip has been reduced
to one compact menu. It also reconfirms that the visual rescue gate is blocked:
the current opening mixes photographic ground with toy-like low-poly trees and
characters, a straight shallow river, bright ambiguous fence/marker props,
flat sparse horizon dressing, and a small-scale bridge/house composition. The
new bridge supports, shoreline clusters, and water surface are technical
increments only. Do not represent the world as presentable until a fresh
independent screenshot review accepts a coherent material/scale/world pass.

### Terrain control-map correction — 2026-07-18

The brown far-bank failure was traced to importing a height image without a
Terrain3D control map and then writing only 25 individual control texels. The
runtime now imports a full 512² manual meadow control map alongside the
heightfield, so the complete 2.4km terrain begins with the intended texture
layer. Headless Terrain3D collision/extent tests pass and the rendered capture
`/tmp/choyce-now/terrain-full-control.png` confirms that the fallback brown is
gone. This is a material-foundation correction only: the capture still rejects
the sparse toy-like trees, rectangular trails, and uncomposed horizon.

### Material and capture-stability follow-up — 2026-07-18

The opening now uses the existing dense forest-floor terrain tile instead of
the lime meadow tile, a separate generated leaf texture only on the curated
oak canopy meshes, and the supplied wood material on their trunks. The live
capture at `/tmp/choyce-now/opening-forest-floor-balanced.png` confirms the
ground is no longer a flat saturated field and the foreground trees are not
larger than the camera frame. The evidence-capture timer was also corrected to
run once and to use Godot's `minute`/`second` dictionary keys; the previous
repeating invalid-key error flood is gone in the following live boot.

This is deliberately **not** visual-gate acceptance. The same capture still
shows incompatible background prop packs, a sparse/regular horizon, a flat
sky, a house/bridge focal composition that lacks lived-in detail, and an
editor-like numbered hotbar. Keep VS-012, VS-013, VS-014 and VS-029 open until
the independent review accepts a coherent rendered opening.

VS-016 is also corrected to start an empty evidence session and accept each
capture point only from its real gameplay event. It must not present the same
spawn frame as evidence of combat, guide interaction, or a region transition.

### Opening safety and evidence follow-up — 2026-07-18

The live opening exposed the raw `szkielet.glb` encounter asset at an
unacceptable giant scale. Normal watchers are now scaled to a little above the
player rather than house height, and stay at their authored remote encounter
locations. The matching visual regression test and editor parse scan pass.

Evidence capture now waits for the runtime's opening-generation settle signal,
instead of scheduling the spawn image from a shell change. Both screenshot and
session-evidence output paths normalize their `user://` roots and use Godot's
`minute`/`second` datetime keys. These are stability corrections only; they do
not satisfy the larger VS-012/VS-013 art and composition gate.

1. **Foundation:** collision dimensions are world metres rather than scaled
   proxy guesses; preserve native materials; use a camera ray and 3D preview
   for TPP building; real ground/dirt collision; a water volume with
   wading/swim physics; continuous exploration music; no legacy Ninja overlay.
2. **Gather → earn → upgrade (VS-020):** place tree and rock resource nodes,
   tool caches/crafting recipes, durability-free axe and pickaxe checks, clear
   feedback, and respawnable resources. The child finds or makes the matching
   tool before harvesting; no timer, grind quota or forced quest.
3. **Discover → drive → reshape (VS-021):** use a verified CC0 vehicle kit
   (Kenney Car Kit is the preferred candidate) for rare parked vehicles.
   Implement arcade CharacterBody driving, enter/exit, camera handoff and
   collision. The bulldozer may remove only tagged temporary scenery and
   build-grid blocks; homes, NPCs, bridge, boundary and protected builds stay
   immune and every removal is restorable.
4. **Identity/ownership (VS-022):** compact bounded swatches/face variants for
   skin, hair, face, top, pants and shoes apply to the actual third-person rig,
   persist locally and never affect gameplay stats.
5. **Optional encounters (VS-023):** replace slime primitives with original,
   non-gory liminal-space creatures (mood-inspired, not named or recognizable
   Backrooms copies), with clear telegraphs, avoidable behavior and parental
   combat gating.

Acceptance requires a rendered child flow: find an axe → cut a tree → receive
wood → find/make a pickaxe → mine stone; find, enter, drive and exit a rare
vehicle; safely restore bulldozer changes; see a chosen character look after a
full replay; and encounter an optional, readable, non-gory liminal creature.

### Opening atmosphere, riverbank and evidence review repair — 2026-07-18

The first curated river crossing has been extended with local Kenney riverbank
habitat: irregular rocks and logs use narrow, world-metre colliders; bushes,
grass and flowers frame both banks outside the bridge and ramp corridor. The
foreground grove now uses the corresponding detailed Kenney bush rather than
the old flat FBX plant. This is a density and contact-detail increment, not a
claim that the opening is visually coherent.

The Sky3D hand-off was repaired after rendered inspection showed that the
runtime was replacing the addon's initialized atmosphere material with a blank
one. The retained project environment now uses Sky3D's initialized material,
including its noise and cumulus texture bindings. The fresh live capture at
`/tmp/choyce-now/opening-sky-material-fixed.png` confirms clouds and daylight
are visible. It also clearly confirms the visual gate remains blocked: terrain,
character and architecture packs still lack a unified high-quality language;
the immediate scene is sparse; and the numbered hotbar/compact arrow control
still need VS-014 review.

Hostile review then found two evidence correctness defects and both are fixed:
the Play-shell listener now retries the separate saved-world launch path and
connects once to the created runtime, while the spawn evidence timer never
force-labels an unsettled opening as valid after eight seconds. The focused
evidence test, Sky3D test, world-renderer test and editor parse scan pass.
VS-016 remains in progress because policy-aware partial finalization and a
real delayed-runtime integration test are still open review risks.

### Current visual-world correction — 2026-07-18

The user is correct that a large coordinate range plus scattered props is not a
world: the current terrain remains too flat, the procedural forest reads as
independent trees, caves and mountains do not yet establish a believable travel
rhythm, and the existing night transition is too dark to navigate. **VS-035**
is now the active visual gate inside VS-012/VS-013: use Terrain3D height and
control maps for a safe opening basin, traversable relief, distant mountain
silhouettes, forest volumes, and deliberate cave approaches. WorldRenderer may
only dress those forms; it must not attempt to fake a forest or mountain with
random prop scatter. Sky3D night needs a legible moon/ambient baseline with
visible silhouette, trails and landmarks, then a rendered day/night traversal
review.

The supplied Ziemek and Gniewko references are also an explicit character
quality requirement, not merely cinematic names. **VS-036** will make their
in-game looks distinct and recognisable within the project’s stylised, safe
character system and retain the face/body attachment contract. A partial local
split-screen implementation already exists; it must be completed and tested
before considering LAN networking. LAN remains a later transport/authority
layer, so it cannot be used to excuse a broken local two-player experience.

Immediate bug repairs made in parallel are not visual-gate acceptance: water is
now rendered as an opaque depth-tested surface while wading, the rare parked
vehicle uses the supplied coherent police-car model rather than an overlapping
primitive tractor body, chair sitting uses an explicit elevated seat transform,
and hit audio no longer stacks the spell-like imported whoosh over physical
punch/kick impacts. Wood and stone gathering now emit dry axe/pickaxe action
cues. The ElevenLabs asset-generation prompts were updated for future sourced
replacement clips; the current environment does not expose an ElevenLabs key,
so the runtime uses a deliberately non-tonal local fallback rather than
silently attempting a network call.

### Opening composition correction — 2026-07-18

Rendered play evidence showed that the initial 5×5 streamed envelope and the
static beach, cave, village and forest centres were all effectively visible
from the spawn. This made the 5.76km² coordinate range read as a single noisy
toy diorama. The four regional destinations now begin 300–580m away, the
repeated full-river collidable rock fence has been removed, and generic
procedural scatter is held outside the 380m composed opening radius. The
starter bridge and livable home are therefore the only intended near-field
destination geometry. This is an evidence-backed cleanup, not VS-035
acceptance: the next review must verify a clean live screenshot, believable
relief/material scale, and a forest/cave journey after travel.

### Traversal-and-making regression gate — 2026-07-18

The reported car, stair, water and tool failures are treated as one gameplay
credibility gate, not four isolated polish issues. **VS-038** replaces the
wheel-contact-dependent vehicle movement with a grounded `CharacterBody3D`
arcade controller: ready-made car/dozer meshes stay visual, while entry,
camera, exit, gravity and Terrain3D collision have one authoritative movement
path. It must prove forward/reverse/turn movement on streamed terrain before
the vehicle is shown as available.

**VS-039** makes creative-mode selection authoritative: the five visible slots
hold axe, pickaxe and blocks; selecting a material stows rather than destroys a
tool; a tool swing is visibly distinct from bare-hand combat; and axe/pickaxe
hits harvest only their matching grounded resources. Block placement must use a
camera aim probe resolved against actual terrain, never a global-y fallback
that silently buries a placed block.

**VS-040** owns traversal contact and water. Player stair/slope snapping and
object colliders must match rendered feet/footprints; the river remains an
opaque, independent surface while its separate Area3D volume drives wading.
Its shader needs an obvious shallow-bank to dark-channel gradient and animated
foam, without transparency sorting or a 65k-vertex one-river performance
spike. Completion requires a live walk/drive/build/harvest/wade pass plus a
cross-agent adversarial review; source inspection and headless tests alone are
not acceptance.

### Interaction/audio reliability correction — 2026-07-18

**VS-041** closes two regressions that break basic sandbox trust: the runtime
must route E/Escape to an occupied vehicle before generic interactions, and
its compact in-world prompt must make egress obvious without restoring the old
debug control legend. Authored Adventure NPC greetings and the optional G-key
fart reactions must ship as pre-generated ElevenLabs recordings on the Voice
bus, so Finder/editor launches do not silently lose speech because they lack
the developer shell's API key. The request-aware remote adapter remains for
un-authored lines, with captions and a local fallback on failure.

### Launcher key-art correction — 2026-07-18

**VS-043** repairs the first-frame regression exposed in the live build: the
realtime 3D intro may not dissolve into the old gradient-plus-squares screen.
At the handoff, trailer chrome/captions disappear while its final rendered
action frame freezes as the launcher background. A quiet vignette provides
contrast and the title/Play affordance moves above the frame, so the child sees
one coherent game image rather than a cinematic followed by a prototype card.

### River and grove grounding correction — 2026-07-18

The first new clean exploration capture exposed a concrete scene-transform
defect: the generated river ribbon already stores world-space Z coordinates,
yet its parent `Area3D` was translated by `z=-24` as well. The visual river
therefore cut through the north-bank house while its swim volume remained at
the bridge. **VS-044** keeps the visual at world origin and moves only the
simple water volume to the crossing; focused coverage now guards that shared
coordinate contract. The same live capture showed that the spawn was still a
lawn, so the opening now uses an asymmetric layered tree frame that keeps the
bridge and routes open. The river foam/emissive wash was restrained to teal so
the supplied animated DUDV material reads as current rather than a pale road.

The subsequent live pass found that the Nature Kit pine palette swatches were
rendering as striped, broken trunks. VS-044 therefore uses the already-local
named trunk/canopy oak model for the opening woodland, applies the local bark
and leaf material per named mesh, and calibrates its source scale to a 5–10m
adult-scale tree. The forest is seeded as eight clustered groves (twelve trees
each), leaving the bridge corridor and two opening routes clear. The supplied
MIT Simple Water package is Godot-3-only, so its DUDV/reflection principle was
ported to the existing Godot-4 shader: the river now has fragment-level channel
depth, moving flow streaks, restrained Fresnel sky reflection, and remains
opaque to avoid the reported disappearing-water sort bug. Fresh direct-play
evidence is `/tmp/choyce-world-audit-water-port.png`; independent visual review
is pending. The scene is still a prototype-level composition and must not pass
the visual gate on this work alone.

The same capture made the starter house's roof-to-wall proportion visibly
wrong. The source `Roof_RoundTiles_8x12` is 6.4m tall at unit scale, but had
been placed at full height above 3.1m walls. The starter shell now calibrates
that roof to the room, adds its matching `Roof_Front_Brick8` caps at both gable
ends, and fits the visible door exactly inside its 2.2m physical leaf. Both the
modular-house and renderer checks pass; the fresh visual evidence is
`/tmp/choyce-world-audit-house-caps.png`.

This is a direct grounding/composition repair, not proof of the visual gate:
the retained capture still shows a prototype HUD, overly sparse near-field
details, disconnected source-asset language, and terrain forms that need a
stronger art pass. Cross-agent visual/traversal review remains required before
VS-044 can close.

### Startup and HUD reliability correction — 2026-07-18

Controlled autoplay uncovered two startup exceptions that headless renderer
coverage did not exercise. The old Nutrition HUD scene had no root script, so
its `CanvasLayer` failed a typed assignment in `GameplayRuntime._ready`; the
next body-progression line also assumed the imported character root was a
`MeshInstance3D`. Either exception skipped the remainder of startup, including
the local authored voice setup. **VS-045** restores the Nutrition HUD script,
keeps its obsolete text panel hidden, resolves the first actual mesh within an
imported character hierarchy, and uses Godot 4's MeshInstance3D blend-shape
API as a safe no-op for models that do not ship matching shapes. This removes
the leaked English overlay and makes the visual/audio bootstrap trustworthy;
it does not make the current world art acceptable.

### Review-driven opening rescue, iteration 2 — 2026-07-18

The first independent review of VS-044 correctly rejected the initial river and
grove pass. The visual water ribbon and its collision did not share a real
meander, the forest began too far beyond the camera, the foreground remained a
lawn, and the photographic leaf tile clashed with low-poly canopy geometry.
The live implementation now uses one sampled bank-pair function for the water
mesh and its 96 overlapping shallow-water volumes, adds non-colliding wet-earth
bank ribbons from the same samples, begins colliding forest masses immediately
beyond the north bank, and layers ready-made bush/grass/rock thickets outside
the two routes. The incompatible photographic leaf source was replaced with a
purpose-built stylised leaf tile after checking the installed local foliage
assets. This pass is evidenced by `/tmp/choyce-live-updated-world.png` and the
focused renderer contract.

That capture also makes the remaining failures unambiguous: the river is still
too geometrically flat, the clearing has too much bare foreground, local
assets still read as a mixed prototype kit, and the default blue-uniform player
does not represent Ziemek or Gniewko. **VS-044 remains in progress**, not in
review, until a fresh adversarial review can judge a materially stronger live
frame. **VS-046** is now the separate, visual-priority hero task: translate the
approved Ziemek/Gniewko concepts into distinct rigged gameplay silhouettes
without using the supplied child photographs as game textures or breaking face,
tool, local-split-screen, or persistence contracts.

Night is also a direct visual-playability constraint. Sky3D now has a 48-minute
day, boosted moonlight, a lowered night sky contribution that actually exposes
ambient energy, and a retained shadowless fill light. The prior configuration
clamped its night contribution above the day value and produced the black live
frame the user reported. The Sky3D regression test covers the changed light
ownership; a live night traversal capture remains required before visual-gate
acceptance.

### Hostile re-review result — 2026-07-18

The required re-review returned **REQUEST_CHANGES** and its evidence is retained
at `.ai/reviews/VS-044-codex-visual-runtime-rereview-2026-07-18.json`. Two
concrete defects were repaired immediately: visible bridge stairs now sit over
matched convex ramp collision instead of generic boxes, and wet river-bank
ribbons no longer carry a global 20cm lift—they slope from the generated water
line to sampled Terrain3D height. Focused Sky3D and renderer contracts pass
after this repair, and `/tmp/choyce-live-grounded-banks.png` is the fresh
direct-play evidence.

The review remains correct on the remaining visual gate failures: the opening
still looks like a sparse kit prototype, the river does not yet read as deep or
moving in the actual camera, and the default blue-uniform protagonist is not a
credible Ziemek or Gniewko. The shadowless night fill is now time-of-day
responsive rather than a daytime wash, but a rendered night traversal capture
is still required. These are implementation blockers, not deferred polish.

### Hero identity correction — 2026-07-18

VS-046 is now in progress. The generic blue uniform is replaced at runtime by
a selective UV/material treatment on the existing animated character rig:
Ziemek's starting garment reads turquoise, his lower garment reads dark cargo,
and a scaled supplied bag mesh is mounted outside the camera-visible back. The
first capsule-clothes experiment was rejected after a live capture because it
read as rigid armour; no such primitive torso/leg proxy is retained. Face
performance, locomotion animation and held-tool sockets stay on the original
character hierarchy, and a focused regression test checks the Ziemek layer and
the clean removal of his backpack when switching to Gniewko.

This does **not** clear the character-art gate. Gniewko still needs a distinct
polished live look and local split-screen selection remains incomplete. The
available generic source rig is materially below the supplied concept-turnaround
quality, so VS-046 needs a real child-proportioned replacement/garment asset
before it can be accepted as visual-rescue evidence.

### Water and forest evidence loop — 2026-07-18

VS-044 now renders the meandering river at 192 longitudinal segments with 12
cross-river strips, correct upward normals, repeated supplied SimpleWater DUDV
flow, and an opaque turquoise/deep-channel material. Collision deliberately
stays at the proven 96 overlapping water volumes. The focused renderer and
bridge contracts pass, and `/tmp/choyce-water-flow-current.png` is the direct
play capture after the runtime uniform correction.

That capture is still **not** visual-gate evidence: from the real third-person
opening view the river remains too much like a broad graphic band, and the
opening composition remains sparse/toy-scale. A CC0 Nature broadleaf test was
captured at `/tmp/choyce-opening-broadleaf-test.png` and removed immediately:
its bark UVs produced visible horizontal striping and its crown overwhelmed the
frame. The supplied Fantasy-Free package is AGPL and `gdTree3D` has no supplied
license file, so neither is bundled without an explicit licensing decision.

### Forest material and contact correction — 2026-07-18

The next approved local reuse is the CC0 Quaternius Ultimate Nature Pack that
was already imported in `data/models/quaternius/nature`. Its Common, Pine and
Birch silhouettes now provide the deep opening forest instead of repeating the
near-field oak across every distance. The first rendered trial correctly
failed: the source's low-poly canopy normals combined with the generic cel
shader into near-black crowns. The repair is deliberately narrow: those four
sources use `forest_foliage.gdshader`, which preserves the local leaf texture
with a bounded ambient floor, while their individual trunk collision profiles
replace one generic forest box. The direct-play capture
`/tmp/choyce-forest-readable-shore-rocks.png` verifies that the black-crown
failure and white bridge-side cliff cube are removed; the latter now uses
irregular ready-made rock meshes.

The cross-agent re-review remained `REQUEST_CHANGES` and is retained at
`.ai/reviews/VS-044-forest-material-rereview-2026-07-18.json`. Its valid
collision finding was repaired: every trunk profile now scales with its
2.45–3.95× visual instance before the collision child cancels inherited
transform scale. The foliage material now retains directional light with a
bounded minimum response instead of being unshaded, and the renderer test
instantiates the deterministic forest to check material overrides plus
scale-matched physical shapes. `/tmp/choyce-forest-lit-scaled-collision.png`
is the fresh live capture after that correction.

The first bank-understorey experiment was rejected from direct play because
the supplied `plant_flatTall` meshes rendered as bright cyan crystal-like
forms. They were removed rather than hidden by another shader. The retained
bush/rock-only replacement at `/tmp/choyce-riverbank-bush-only.png` has no
neon artifact and keeps the bridge lane open, but it remains insufficient:
the foreground is still predominantly lawn and the river is still a broad
graphic stripe. The next correction must introduce actual terrain-conforming
bank relief and a bridge-to-forest travel frame, not merely add more props.

Terrain3D now owns a bounded 2–2.5m outer-bank shoulder around the authored
opening crossing. Its pure heightfield contract proves that the spawn, channel
and bridge ramp remain flat while the north bank gains visible relief; the
direct-play test is `tests/adapters/inbound/test_terrain3d_world_adapter.gd`.
This is still not acceptance evidence: the first capture needs an unobstructed
child-height bridge-to-forest frame before the terrain/visual cohesion can be
judged.

The hotbar has also removed its visible `1–5` control legend. It remains
icon-led, with non-rendered tooltips retaining assistive/keyboard names; its
focused contract is `tests/adapters/inbound/test_hotbar_image_hud_contract.gd`.
`/tmp/choyce-image-hotbar-no-numbers.png` confirms the numbered overlay is
gone, though the desktop capture is not the final UI quality gate.

This is still only a repair, not VS-044 acceptance. The retained capture shows
that the clearing remains overly open, the river still reads as a graphic band,
and the new forest needs understorey, bank depth and a bridge-to-forest traversal
capture before it can be described as an engaging natural space.

### Terrain collision, grounded river dressing, and image HUD verification — 2026-07-18

The first Terrain3D bank pass exposed a safety flaw: asking Terrain3D to build
dynamic collision is not proof that its local physics mesh already exists. The
flat fallback collider now remains active at session start and is disabled only
after four physics frames and direct rays confirm Terrain3D below the player,
camp dressing, and both north-bank samples. This is covered by the installed
extension—not only height-map maths—in
`tests/adapters/inbound/test_terrain3d_world_adapter.gd`; the direct Adventure
boot logs the successful handoff.

`/tmp/choyce-opening-bank-props-grounded.jpg` is the first unobscured opening
capture after that repair. It also revealed and corrected a concrete placement
bug: several nominal riverbank foliage entries were inside the meandering swim
channel, producing the floating cyan/white plants seen in play. The rendered
bank now uses low textured bushes instead of the offending tall cards, all
named riverbank props are regression-checked outside the physical water
cross-section, and the water grade is a deeper muted stream rather than a pale
cyan strip.

The hotbar is now verified by constructing the real HUD: it has five
texture-backed slots, no visible `Label` child, and a contrast-checked selected
border. This satisfies only the icon-first control repair. Neither the HUD nor
the opening world passes the final visual gate yet: the clean capture still
shows too much open lawn, mixed source-model language and a weak bridge-to-
forest discovery frame. The next visual task is therefore a deliberately
curated landmark/forest approach, not another random prop scatter.

## Explicit non-goals for the next implementation batch

- Do not add another world type.
- Do not turn optional discovery prompts into a mandatory quest chain or
  completion checklist.
- Do not add bespoke/generated assets before checking the existing asset and
  sample libraries against a verified visual gap.
- Do not make Ollama or microphone access a prerequisite for the Adventure sandbox loop.
- Do not mark the vertical slice complete from headless tests alone.
- Do not add dynamic LLM-driven NPCs or monsters before the visual/playable demo
  gate is accepted; keep that idea bookmarked for a later bounded experiment
  using tailnet LiteLLM decisions, ElevenLabs dialogue, allowlisted actions,
  moderation, budgets, fallbacks, and audit logs.

## Sandbox-loop and co-op priority — 2026-07-18

The next systems slice is deliberately one connected free-play loop, not more
isolated mechanics:

`real tree/rock → shared pictorial inventory → chosen craft → held item →
camera-ray build → undo/save → play together`

VS-049 owns the loop. It will keep creative mode as the default: the shipped
safe block/tool catalog is available from inventory, while gathering still gives
the child a meaningful, non-grindy reason to explore and make recipes. Inventory
opens only on an explicit action, owns the keyboard only while focused, and keeps
the image-first HUD uncluttered during exploration. Crafting starts with clear,
bounded recipes (food, stick, iron sword) and uses the existing held-item,
resource, build-grid and save seams rather than making a parallel inventory.

VS-050 is the immediate multiplayer target: reliable local split-screen. Both
children must inhabit one World3D and mutate the same inventory/resources/build
state before any network work begins. The existing research makes LAN/P2P a
separate host-authority, consent, safe-role, save-conflict and disconnect
problem; it is tracked as VS-051 and remains design-only until local co-op is
proven and reviewed. This keeps private family multiplayer possible without
pretending a second viewport is a peer-to-peer implementation.

Implementation evidence, 2026-07-18: VS-049 now has a shared local-inventory
fallback as well as the rules-backed path, so a sandbox launched without the
optional rules adapter saves and restores its collected materials and placed
blocks. VS-050 now launches from PlayShell into Ziemek + Gniewko local split
screen over one World3D and BuildGrid. Each child has an explicit inventory
control (P1 `I`, P2 keypad `.`), a complete safe creative catalog, shared
resource collection/crafting, actor-owned crafted gear, and restored solo
arrow bindings when co-op closes. LAN/P2P remains intentionally unimplemented
behind VS-051's parent-authorized host/save safety gate.

Local-co-op control hardening, 2026-07-18: P2 no longer follows P1's mouse or
Q/E camera movement, and instead turns with its own keypad `7`/`9` pair. The
same shared `BuildGrid` now receives a P1 undo exactly once—P2 cannot consume
the global `U` fallback—while P2 retains keypad `*` for its own undo. The
regression suite exercises the isolated pointer path, P2 look rotation,
shared-resource craft/build state, save/restore and teardown. This is still
one-screen local co-op, not a LAN or P2P implementation; VS-051 owns the
separate parent-authorized transport boundary.

Visual-route follow-up, 2026-07-18: the opening bridge no longer renders as a
grid of generic floor tiles with unrelated fence props. It now uses the shipped
Kenney Nature Kit centre, side, and rounded-cap bridge modules over the existing
continuous walk surface. A real `CharacterBody3D` regression now walks every
south/north ramp and deck checkpoint in both directions; that test exposed and
fixed a rail-collider axis error which had reached into the middle of the deck.
This improves the authored crossing and removes an invisible block, but does
not close the visual-rescue gate: fresh rendered opening/river evidence and an
independent visual review are still required.

## References

- `.ai/tasks/backlog.yaml`
- `thoughts/shared/plans/2026-07-19-thin-slice-adventure-a-to-z.md`
- `thoughts/shared/reviews/adv-BB-combat-design-2026-05-19.md`
- `thoughts/shared/reviews/adv-Y-fight-feel-2026-05-19.md`
- `docs/release/release-exit-criteria.md`
- `docs/security/RELEASE_THREAT_MODEL.md`

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

## References

- `.ai/tasks/backlog.yaml`
- `thoughts/shared/plans/2026-07-19-thin-slice-adventure-a-to-z.md`
- `thoughts/shared/reviews/adv-BB-combat-design-2026-05-19.md`
- `thoughts/shared/reviews/adv-Y-fight-feel-2026-05-19.md`
- `docs/release/release-exit-criteria.md`
- `docs/security/RELEASE_THREAT_MODEL.md`

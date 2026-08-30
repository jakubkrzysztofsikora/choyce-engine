# Vision and Gameplay Sweep - 2026-08-30

## Verdict

**BLOCKED.** The visual QA bridge captures the full operating-system display
rather than a Godot-owned game viewport. It retains and attempts to upload
those captures to the configured vision provider. Do not run external visual
assertions again until this boundary is corrected and independently reviewed.

## Scope and Sessions

| Session | Coverage | Result |
| --- | --- | --- |
| Shell handoff | launcher, Create, Play, Polish UI | Blocked: capture scope invalid; LiteLLM visual requests timed out |
| Render presentation | texture loading, toon/foliage/water shaders, river, bridge, settlement composition | Technical contracts pass; the 320x240 diagnostic captures do not establish production material quality |
| Sandbox loop | gathering, inventory, crafting, build persistence, NPC interaction, combat feedback | Behavioral contracts pass; warnings and visual-evidence gaps remain |

The attempted live session used the debug-only loopback bridge with both
required gates enabled. It produced 3840x1600 evidence frames under
`.ai/manual-qa/LITELLM-VISION-SWEEP-20260830/`; these files are sensitive
because they may contain unrelated desktop content. They are intentionally
untracked and must not be copied, committed, or uploaded.

## Blocking Findings

1. **Critical - full desktop capture and external disclosure.**
   `src/adapters/outbound/test_bridge_adapter.gd:85` calls
   `DisplayServer.screen_get_image(0)`, which captures the primary macOS
   display rather than the game window. Inspected evidence contains desktop
   chrome and unrelated applications. `scripts/testing/ai_vision_runner.py:205`
   then packages the received bytes as an `input_image` for LiteLLM. This
   violates the adapter's no-PII claim and the child-safe visual QA boundary.
   Replace it with a game-owned viewport or SubViewport texture capture; fail
   closed when none is available. There must be no OS-screen fallback.

2. **Critical - visual testing must remain disabled until scoped capture is
   verified.** `scripts/testing/ai_vision_runner.py:321` persists the raw bridge
   response before inference resizing, so the original desktop evidence is also
   retained locally. Once the bridge is fixed, validate `image/png`, capture
   provenance, and viewport dimensions before writing evidence or allowing an
   external request. Add an integration test that proves the provider payload
   and evidence consist only of the game canvas.

3. **High - Tailnet LiteLLM Responses visual route is unavailable for this
   sweep.** `opencode/gpt-5.6` timed out on three 1280px-edge inference images
   after 90 seconds each. A separate `gemma-3-4b-it` probe timed out after 45
   seconds. The gateway's `/v1/models` endpoint answered promptly, so the
   failure is specific to the vision request path or its backing models, not
   basic Tailnet reachability. This is an environment/integration issue, not a
   game defect; it must not be reported as a failed visual assertion.

## Gameplay and Rendering Findings

4. **High - the bridge does not publish the state used by its scenario.**
   `KF-001` expects `session.current_shell`, but the captured bridge state was
   `{}` and the scenario failed after navigating to Create. Search found no
   `set_state_section` call that publishes the shell state. This makes the
   runner's hard state assertions non-actionable until state publication is
   wired and covered.

5. **Medium - relaunch logs duplicate palette registration warnings.** The
   fresh `tests/play/run_play_observation.gd` run passes all eleven objectives,
   but its second sandbox launch logs duplicate `block_wood`, `block_stone`,
   `block_glass`, and `beam_long` registration warnings from
   `levels/sandbox_level.gd:124` through `gameplay/building/build_system.gd:103`.
   The duplicate is currently ignored, but it indicates global build-palette
   lifecycle is not idempotent across a session relaunch.

6. **Medium - the settlement renderer knowingly omits sheep.**
   `src/adapters/inbound/gameplay/homestead_spawner_3d.gd:32` maps `sheep` to an
   empty model path, while farmer and shepherd sets request sheep. Fresh world
   and settlement tests repeatedly log a skip warning. The homestead contracts
   pass, but farming/shepherd visual composition is incomplete.

7. **Medium - combat feedback unit test masks scene-tree errors.**
   `tests/adapters/inbound/test_combat_hit_feedback.gd:48` deliberately invokes
   real gameplay methods on an off-tree runtime. The test prints PASS but also
   triggers `data.tree is null` errors from damage-number and hit-stop paths.
   It proves emitted feedback wiring, not an error-free rendered combat hit.

8. **Medium - visual quality coverage is insufficient for the requested art
   review.** The shader and world-renderer contracts validate resource loading,
   material assignment, animation, collision, and river composition. The
   available render audit frames are only 320x240 diagnostic scenes and do not
   capture an in-game Adventure camera, NPC dialogue, gathering impact, craft
   inventory, placed building, or live combat encounter. They cannot support a
   product-quality judgment about textures, lighting, character readability,
   or child-facing combat telegraphs.

## Fresh Verification Evidence

- `godot --headless --path . --script tests/play/run_play_observation.gd`
  completed all 11 behavior objectives: launch, shared build placement/removal,
  save/relaunch, and input/session cleanup. It emitted duplicate palette and
  shutdown-resource warnings noted above.
- `godot --headless --path . --script
  tests/adapters/inbound/test_sandbox_gather_craft_loop.gd` confirmed a real
  wood interaction updates inventory and produces the starter meal.
- `godot --headless --path . --script
  tests/adapters/inbound/test_sandbox_inventory_crafting_loop.gd` confirmed
  inventory focus handling plus meal, stick, and iron-sword recipes.
- `godot --headless --path . --script
  tests/adapters/inbound/test_combat_hit_feedback.gd` reported PASS with the
  scene-tree errors described above.
- `godot --headless --path . --script
  tests/adapters/inbound/test_world_renderer_kaykit_loads.gd`,
  `test_world_renderer_toon_shader.gd`, and
  `tests/integration/test_visual_settlement_rendering.gd` passed their technical
  renderer contracts while producing the known missing-sheep warnings.

## Required Follow-up Order

1. Replace OS-level screenshot capture with a verified Godot-owned viewport
   capture, then add a failing privacy regression test before implementation.
2. Keep both Anthropic and LiteLLM visual uploads disabled until the scoped
   capture test, payload-provenance validation, and an independent safety
   review pass.
3. Diagnose the LiteLLM Responses timeout with a safe synthetic viewport image
   only after step 1; select a confirmed image-capable route and retain timing
   evidence.
4. Publish shell state to the debug bridge and create longer, in-game capture
   sessions for NPC dialogue, gathering, crafting, building, and combat.
5. Resolve the relaunch palette lifecycle, sheep asset omission, and off-tree
   combat-test errors, then rerun the three-session sweep.

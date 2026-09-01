# Sandbox Kit Live Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the enhanced Sandbox Kit the clearly reachable default play route, repair mouse look in its actual player controller, and prove the kit graphics/mechanics are live without bypassing safe persistence and session boundaries.

**Architecture:** `GameplayRuntime` remains the composition root. `PlayShell` and `InboundMain` select the seeded `sandbox_kit` project when no explicit world is chosen; `GameplayRuntime` mounts the existing `SplitScreenManager`, `SandboxKitBridge`, and Kit level without changing their bridge contracts. `SandboxPlayer` owns the scoped P1 mouse recapture transition, while the Kit overlay presents active mechanics and quality state.

**Tech Stack:** Godot 4.6, GDScript, existing `SandboxKitBridge`, `SandboxPersistenceService`, `SplitScreenManager`, headless SceneTree regressions, and windowed Godot input integration.

**Spec:** `docs/superpowers/specs/2026-09-01-sandbox-kit-live-integration-design.md`

## Global Constraints

- Do not add a second save format: Kit state continues through `SandboxKitBridge` and `SandboxPersistenceService` only.
- Preserve existing parental roster and block budgets before joining Kit players.
- The cursor recapture click must not trigger build, grab, throw, or attack.
- Raw mouse input remains keyboard-player-only; gamepad players use namespaced actions.
- Adventure, Farm, and City remain explicitly selectable; this plan changes the default entry only.
- Windowed tests own the OS cursor assertion; headless tests must skip that assertion with a clear message.
- Keep changes in Godot inbound adapters and tests; no domain or external AI boundary is added.

---

### Task 1: Repair Sandbox Kit Mouse Recapture

**Files:**
- Modify: `gameplay/player/sandbox_player.gd:121-131`
- Create: `tests/gameplay/test_sandbox_player_mouse_input.gd`

**Interfaces:**
- Consumes: `SandboxPlayer.device`, `MultiplayerInputSystem.KEYBOARD_DEVICE`, `InputEventMouseButton`, `InputEventMouseMotion`.
- Produces: `SandboxPlayer._unhandled_input(event)` captures visible-cursor P1 clicks without triggering a gameplay action, then updates `_yaw` and `_pitch` on captured mouse motion.

- [ ] **Step 1: Write the failing windowed regression**

```gdscript
func _test_visible_world_click_recaptures_without_gameplay_action() -> void:
    var player := _spawn_keyboard_player()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    player._unhandled_input(click)
    _expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "world click recaptures")
    _expect(not Input.is_action_pressed("attack"), "recapture click is inert")
```

Add a second assertion that sends `InputEventMouseMotion.relative = Vector2(32, 0)` and verifies `_yaw` changes. Run these assertions only when `DisplayServer.get_name() != "headless"`; print a single `SKIP` line otherwise. Add a P2 profile/device test that asserts visible-cursor raw mouse events leave `Input.mouse_mode` and P2 yaw unchanged.

- [ ] **Step 2: Run the new test and verify it fails**

Run: `godot --path . --script tests/gameplay/test_sandbox_player_mouse_input.gd`

Expected: the windowed test fails at `world click recaptures`, because `SandboxPlayer._unhandled_input()` currently processes only `InputEventMouseMotion`.

- [ ] **Step 3: Implement the minimum transition in `SandboxPlayer`**

Place this branch after the keyboard-device guard and before the mouse-motion branch:

```gdscript
if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
    if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and event.pressed:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    return
```

Do not press `attack`, toggle build, or call interaction APIs in this branch. Keep the existing mouse-motion branch unchanged except for using the same captured-mode predicate.

- [ ] **Step 4: Verify deterministic and windowed behavior**

Run:

```sh
godot --headless --path . --script tests/gameplay/test_sandbox_player_mouse_input.gd
godot --path . --script tests/gameplay/test_sandbox_player_mouse_input.gd
godot --headless --path . --script tests/e2e/run_sandbox_kit_suite.gd
```

Expected: headless emits the documented OS-capture skip and passes device isolation; windowed passes recapture, inert click, and yaw; Kit persistence/session checks stay green.

- [ ] **Step 5: Commit the isolated fix**

```sh
git add gameplay/player/sandbox_player.gd tests/gameplay/test_sandbox_player_mouse_input.gd
git commit -m "fix: restore sandbox kit mouse look"
```

### Task 2: Make Enhanced Kit State Visible In-Session

**Files:**
- Modify: `src/adapters/inbound/gameplay/gameplay_runtime.gd:4363-4384`
- Modify: `core/systems/split_screen_manager.gd:154-170`
- Modify: `tests/e2e/run_sandbox_kit_suite.gd:207-266`

**Interfaces:**
- Consumes: `SplitScreenManager.last_graphics`, `PlayerRegistrySystem`, Kit overlay CanvasLayer.
- Produces: a `SandboxKitOverlay/ModeRibbon` label with child-readable mechanics and a `SandboxKitOverlay/QualityLabel` label derived from actual active player count and graphics tier result.

- [ ] **Step 1: Add failing Kit-overlay assertions**

In `_check_runtime_kit_session_flow()`, after asserting the Kit stage mounted, assert:

```gdscript
var overlay := runtime.get_node_or_null("SandboxKitOverlay")
_check(overlay != null, "S4 Kit overlay mounted")
_check(overlay.get_node_or_null("ModeRibbon") != null,
    "S4 Kit overlay explains build, grab, and throw")
_check(overlay.get_node_or_null("QualityLabel") != null,
    "S4 Kit overlay identifies active player/graphics state")
var stage := runtime.get("_sandbox_kit_stage") as SplitScreenManager
_check(stage != null and not stage.last_graphics.is_empty(),
    "S4 graphics profile applied to Kit stage")
```

- [ ] **Step 2: Run the E2E suite and verify it fails on missing labels**

Run: `godot --headless --path . --script tests/e2e/run_sandbox_kit_suite.gd`

Expected: S4 reports missing `ModeRibbon` and `QualityLabel`; existing bridge and safety checks pass.

- [ ] **Step 3: Build a non-interactive Kit ribbon**

In `_build_sandbox_kit_overlay()`, add two labels beneath `ExitBar` with `mouse_filter = Control.MOUSE_FILTER_IGNORE`:

```gdscript
var ribbon := Label.new()
ribbon.name = "ModeRibbon"
ribbon.text = "PIASKOWNICA  |  Buduj  |  Chwyć  |  Rzuć"

var quality := Label.new()
quality.name = "QualityLabel"
quality.text = _sandbox_kit_quality_text()
```

Add `_sandbox_kit_quality_text() -> String` to read `PlayerRegistrySystem.instance.count()` and `_sandbox_kit_stage.last_graphics`. It must return plain child-readable copy such as `"1 gracz · pełne światło"` or `"2 graczy · wspólna przygoda"`, never raw renderer property names. In `SplitScreenManager`, keep `last_graphics` as the sole source of applied tier data; do not duplicate graphics-profile logic in `GameplayRuntime`.

- [ ] **Step 4: Verify Kit presentation and regression suite**

Run:

```sh
godot --headless --path . --script tests/e2e/run_sandbox_kit_suite.gd
godot --headless --path . --script tests/adapters/inbound/test_play_shell_local_coop_launch.gd
```

Expected: the Kit suite proves overlay nodes and populated `last_graphics`; local-co-op Adventure remains unaffected.

- [ ] **Step 5: Commit the visual proof slice**

```sh
git add src/adapters/inbound/gameplay/gameplay_runtime.gd core/systems/split_screen_manager.gd tests/e2e/run_sandbox_kit_suite.gd
git commit -m "feat: show active sandbox kit mechanics"
```

### Task 3: Promote Piaskownica as the Default Play Entry

**Files:**
- Modify: `src/adapters/inbound/main.gd:1126-1168`
- Modify: `src/adapters/inbound/scenes/play/play_shell.gd:246-307`
- Modify: `tests/adapters/inbound/test_play_shell_direct_launch.gd`
- Modify: `tests/play/run_play_observation.gd:43-114`

**Interfaces:**
- Consumes: seeded `<profile>_starter_sandbox_kit` project, `ProjectStorePort.list_projects()`, and `PlayShell.launch_world_by_id(project_id, world_id)`.
- Produces: no explicit selection defaults to the playable Sandbox Kit project; explicit card selection keeps launching the chosen project; Play cards identify the Kit as `Piaskownica: Buduj i Baw Się`.

- [ ] **Step 1: Write default-selection regression**

Extend `test_play_shell_direct_launch.gd` with an in-memory store containing an Adventure project and an eligible `sandbox_kit` project. Add a test for the composition-root default resolver that expects the Kit project ID only when no explicit project is set. Add a companion test that verifies an explicit Adventure project remains the selected ID.

Use a small local store fixture with both projects:

```gdscript
var kit := Project.new("kid_1_starter_sandbox_kit", "Piaskownica")
kit.template_id = "sandbox_kit"
kit.add_world(_playable_world("kit_world", "sandbox_kit"))
var adventure := Project.new("kid_1_starter_adventure", "Wyspa skarbów")
adventure.template_id = "adventure"
adventure.add_world(_playable_world("adventure_world", "adventure"))
```

- [ ] **Step 2: Run direct-launch and observation tests to establish red behavior**

Run:

```sh
godot --headless --path . --script tests/adapters/inbound/test_play_shell_direct_launch.gd
godot --headless --path . --script tests/play/run_play_observation.gd
```

Expected: the new default resolver assertion chooses Adventure or returns an empty project instead of the Kit; the observation test currently relies on a manual `CHOYCE_AUTOPLAY` Kit override.

- [ ] **Step 3: Change only the default resolver and card presentation**

In `InboundMain`, update the no-explicit-selection resolver to prefer `<profile>_starter_sandbox_kit` when it exists, is owned by the active kid profile, and has a playable world. Preserve the existing Adventure fallback if the Kit starter is absent or invalid.

In `PlayShell._build_world_picker_cards()`, render the Kit card first and use:

```gdscript
"🧱\nPiaskownica: Buduj i Baw Się\nBuduj · Chwyć · Rzuć"
```

Do not auto-start a world simply on opening the Play shell. The primary/default target is selected for the existing Play action; a child retains the choice to click Adventure, Farm, or City.

Remove the explicit Kit-only override from `run_play_observation.gd`; assert that its normal default launch enters `sandbox_kit` and mounts `SandboxKitStage`.

- [ ] **Step 4: Verify defaulting and explicit world choice**

Run:

```sh
godot --headless --path . --script tests/adapters/inbound/test_play_shell_direct_launch.gd
godot --headless --path . --script tests/play/run_play_observation.gd
godot --headless --path . --script tests/e2e/run_sandbox_kit_suite.gd
```

Expected: default launch uses the Kit without test-only environment selection, direct Adventure launch still uses Adventure, and Kit bridge/safety behavior stays green.

- [ ] **Step 5: Commit the entry-point change**

```sh
git add src/adapters/inbound/main.gd src/adapters/inbound/scenes/play/play_shell.gd tests/adapters/inbound/test_play_shell_direct_launch.gd tests/play/run_play_observation.gd
git commit -m "feat: make sandbox kit the default play route"
```

### Task 4: Review, Full Verification, and Live Handoff

**Files:**
- Modify only if verification exposes an in-scope defect from Tasks 1-3.
- Create: `.ai/reviews/sandbox-kit-live-integration-review-2026-09-01.json`

**Interfaces:**
- Consumes: completed commits from Tasks 1-3 and their test evidence.
- Produces: an independent review decision covering input ordering, child safety, save boundaries, graphics presentation, and explicit Adventure selection.

- [ ] **Step 1: Run the combined targeted suite**

Run:

```sh
godot --headless --path . --script tests/gameplay/test_sandbox_player_mouse_input.gd
godot --path . --script tests/gameplay/test_sandbox_player_mouse_input.gd
godot --headless --path . --script tests/e2e/run_sandbox_kit_suite.gd
godot --headless --path . --script tests/adapters/inbound/test_play_shell_direct_launch.gd
godot --headless --path . --script tests/adapters/inbound/test_play_shell_local_coop_launch.gd
godot --headless --path . --script tests/play/run_play_observation.gd
git diff --check
```

- [ ] **Step 2: Request and record an independent review**

Ask a reviewer to inspect the final diff and evidence. The review JSON must use the repository schema:

```json
{
  "task_id": "sandbox-kit-live-integration",
  "reviewer": "codex",
  "decision": "approve",
  "findings": []
}
```

The reviewer must reject any change that routes save state outside `SandboxKitBridge`, lets the recapture click invoke a gameplay action, bypasses player/block caps, or removes explicit Adventure selection.

- [ ] **Step 3: Launch the actual current project and confirm process ownership**

Run:

```sh
open -na /Applications/Godot.app --args --path /Users/jakubsikora/Repos/choyce-engine
pgrep -fl "/Applications/Godot.app/Contents/MacOS/Godot.*choyce-engine"
```

Expected: a live Godot process points at this workspace. Manual handoff checks: start the default Kit route, read the `Buduj / Chwyć / Rzuć` ribbon, press Escape, click empty world once, move the mouse, and use the visible `Wróć` button.

- [ ] **Step 4: Commit the review evidence and push**

```sh
git add .ai/reviews/sandbox-kit-live-integration-review-2026-09-01.json
git commit -m "docs: review sandbox kit live integration"
git push origin main
```

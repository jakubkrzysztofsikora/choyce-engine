# Godot AI Feedback Loop

## Executive finding

The cheapest reliable loop for this project is a three-layer loop:

1. **Headless contract checks** for scene loading, input routing, asset presence, and gameplay state.
2. **GPU render audits** for the sandbox camera, ground, materials, lighting, and authored composition.
3. **One live runtime probe** that drives mouse, keyboard, and ESC through the actual window and captures before/after frames.

The current sandbox already has pieces of all three layers. The next repair should make them converge on one authored presentation path instead of continuing to tune the procedural `SandboxLevel` in isolation.

## Evidence from Godot documentation

### Input and `SubViewport`

Godot's `SubViewport` documentation says that a standalone `SubViewport` does not receive `InputEvent`s by default, and that placing it inside a `SubViewportContainer` is the normal way to propagate input. It also requires a non-zero viewport size and an active render/update path for visible output. [1]

That maps directly to this repository's unresolved mouse-look report:

- `core/systems/split_screen_manager.gd` creates each gameplay viewport inside a `SubViewportContainer`.
- It currently sets `vp.handle_input_locally = false`.
- `gameplay/player/sandbox_player.gd` listens in `_input`, but the player lives under the disabled world-host viewport rather than the pane viewport.
- A mouse drag therefore has no proven delivery path to the player that owns the camera.

The next implementation should test the boundary explicitly, not infer it from a unit test that calls `_input` directly. The live acceptance test must inject a real `InputEventMouseMotion` at the pane/window boundary and assert that the camera transform changes.

Godot's input examples also recommend the `InputEvent`/`InputMap` path for device-specific behavior and show mouse capture using `Input.MOUSE_MODE_CAPTURED`. [2] The project should keep ESC as a capture toggle in gameplay and reserve session teardown for an explicit overlay action.

### Scene ownership and lifecycle

Godot's SceneTree documentation describes scene instantiation as loading a packed scene, adding its root to the tree, then running enter-tree/ready callbacks. [3] This is relevant because the sandbox currently constructs a large authored village procedurally in `_ready()` while the proven Adventure route lets `WorldRenderer` own the authored world presentation.

The safer boundary is:

- `GameplayRuntime` owns the session and shared services.
- A presentation adapter owns imported terrain, materials, dressing, and camera-facing composition.
- `SplitScreenManager` owns panes and camera attachment only.
- `SandboxPlayer` owns movement, aim state, and gameplay rays only.

This preserves the repository's hexagonal intent and avoids making gameplay correctness depend on the order in which many raw GLTF fragments are assembled.

### Command-line and repeatable runs

Godot's command-line documentation supports `--path`, `--scene`, `--headless`, `--quit`, `--quit-after`, verbose output, and custom user arguments after `--`. [4] That supports a fast matrix of focused checks rather than repeated manual editor launches.

Recommended commands for this repository:

```bash
godot --headless --path . --script tests/gameplay/test_sandbox_art_assets.gd
godot --headless --path . --script tests/gameplay/test_sandbox_player_mouse_input.gd
godot --headless --path . --script tests/e2e/run_sandbox_kit_suite.gd
godot --path . --script tests/play/run_render_audit.gd
CHOYCE_AUTOPLAY_OVERRIDE=local_kid_1_starter_sandbox_kit ./scripts/launch-game.sh --solo
```

The first three are cheap logic gates. The render audit must run with a real GPU because the repository's own harness documents that the null/headless renderer produces black SubViewport textures and cannot validate visual quality.

## Evidence from Godot AI tooling

### Godot AI (`hi-godot/godot-ai`)

The project advertises a live-editor MCP integration with scene hierarchy inspection, scene/script/node editing, signal wiring, material/UI configuration, project execution, log reading, runtime state inspection, screenshots, and an in-editor GDScript test runner. Its testing guidance requires synchronous small tests, tracks temporary nodes for cleanup, detects zero-assertion tests, and preserves per-test results. [5][6]

Useful pattern for Choyce:

- Keep the existing focused GDScript tests as the source of truth for contracts.
- Add a small live-runtime suite for the pane input boundary and camera transform.
- Capture a screenshot and logs on every failed visual probe.
- Do not ask an AI model to judge a scene from code alone; pair scene-tree facts with a GPU frame.

### Godot MCP Native (`yurineko73/Godot-MCP-Native`)

The project advertises broad scene/node/editor/debug/runtime/input/test tooling and a progressive `gdmcp` CLI. Its CLI reference emphasizes compact discovery, on-demand schemas, runtime tree/node inspection, input sequences, dry-run support for writes, and explicit configuration. [7][8]

This is a good fit for a cheap feedback loop if installed locally, because it avoids loading a large tool catalog into every AI turn. The most valuable capabilities for this bug are runtime scene tree, runtime node inspection, input sequences, logs, and screenshots—not bulk scene generation.

### Other tools considered

- `ee0pdt/Godot-MCP` provides broad project/scene/node/script access, but its README is less explicit about modern runtime probing and progressive tool discovery. [9]
- `youichi-uda/godot-mcp-pro` exposes a large runtime/scene/input/debug surface and a progressive CLI, but the README identifies the server as a paid package. It is a possible convenience tool, not a prerequisite. [10]

## Repo-specific recommendations

### 1. Fix the actual mouse boundary first

Add a live diagnostic that records:

- pane viewport receiving the motion event;
- player `_yaw` before/after;
- camera global transform before/after;
- current mouse mode;
- whether the event was consumed.

Then choose one single routing design:

- **Preferred for solo:** route mouse motion from the active root viewport to P1's controller and keep the pane viewport visual-only; or
- **Preferred for real split-screen:** enable local handling on each pane viewport and route events to the player whose pane contains the mouse.

Do not maintain both `_input` and `_unhandled_input` implementations as competing paths.

### 2. Stop using raw village fragments as the visual source of truth

The screenshot shows the characteristic symptoms of a fallback composition: a large flat green plane, cropped/over-scaled building pieces, weak contact shadows, and materials that do not match the authored Adventure presentation.

The next scene change should reuse the existing `WorldRenderer` dressing/material/terrain path, or extract its authored dressing into a shared presentation adapter consumed by both Adventure and Sandbox Kit. `SandboxLevel` should then add only kit-specific interaction points: campfire, build palette, gym, homestead, NPC interaction, and pond.

Acceptance criteria for the authored path:

- ground has visible albedo/normal detail at play scale;
- every hero's feet contact the ground;
- near houses are fully framed and not assembled from visibly mis-scaled wall fragments;
- foliage, houses, props, and terrain share one material language;
- the opening camera communicates a traversable village, not an overhead asset test.

### 3. Make the normal launcher deterministic

The launcher already contains a safe starter-project resolver and idempotent seeding logic. The remaining Play-shell empty state should be tested through the real button path, not only autoplay. A non-destructive default world selection should resolve the playable starter world before rendering the library empty-state copy.

Do not use the destructive New Game dialog as a repair mechanism.

### 4. Add a one-command visual loop

Create a script or Make target that:

1. runs the focused headless tests;
2. runs the GPU render audit and writes PNGs;
3. launches the solo sandbox with a deterministic profile;
4. waits for a readiness marker;
5. captures a wide frame and a play-scale frame;
6. reports the exact image paths and log tail.

The repository already has `tests/play/run_render_audit.gd`, `tests/play/run_play_observation.gd`, `scripts/launch-game.sh`, and `scripts/testing/ai_vision_runner.py`. Compose these instead of introducing a second test harness.

### 5. Use AI as a tight observer, not an unconstrained scene author

The model should receive, per iteration:

- the changed file diff;
- focused test output;
- scene-tree/runtime-node facts;
- one wide GPU frame;
- one play-scale GPU frame;
- the exact user-visible regression.

It should return a short diagnosis, one bounded change, and an acceptance check. This minimizes context and prevents visual drift from speculative asset rewrites.

## Proposed acceptance matrix

| Layer | Check | Pass condition |
|---|---|---|
| Contract | Sandbox art test | Imported hero has texture and animation; authored assets resolve |
| Contract | Mouse input test | Real boundary event changes yaw and camera transform |
| Contract | Sandbox E2E | Build, grab, persistence, ESC capture toggle, and teardown pass |
| Render | Wide frame | Sky, village, ground, and player are all readable |
| Render | Play-scale frame | Feet contact ground; materials are textured; camera is not overhead |
| Live UX | Launcher | One click reaches a playable starter world |
| Live UX | ESC | First press releases capture; no session teardown; overlay button exits |
| Live UX | Mouse | Drag rotates POV continuously while captured |

## Sources

1. Godot Engine, “SubViewport,” stable documentation: https://docs.godotengine.org/en/stable/classes/class_subviewport.html
2. Godot Engine, “Input examples” and “Using InputEvent,” stable documentation: https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html and https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html
3. Godot Engine, “SceneTree,” stable documentation: https://docs.godotengine.org/en/stable/tutorials/scripting/scene_tree.html
4. Godot Engine, “Command line tutorial,” stable documentation: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
5. hi-godot, “Godot AI,” repository README: https://github.com/hi-godot/godot-ai
6. hi-godot, “GDScript Testing — Writing and Running Test Suites”: https://github.com/hi-godot/godot-ai/blob/main/docs/testing.md
7. yurineko73, “Godot MCP Native,” repository README: https://github.com/yurineko73/Godot-MCP-Native
8. yurineko73, “gdmcp CLI Reference”: https://github.com/yurineko73/Godot-MCP-Native/blob/main/docs/current/gdmcp-cli-reference.md
9. ee0pdt, “Godot MCP,” repository README: https://github.com/ee0pdt/Godot-MCP
10. youichi-uda, “Godot MCP Pro,” repository README: https://github.com/youichi-uda/godot-mcp-pro

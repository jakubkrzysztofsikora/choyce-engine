# LiteLLM Vision QA Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable debug-only, localhost-bound AI visual QA runs through the existing Tailnet LiteLLM Responses API without requiring an Anthropic API key.

**Architecture:** `InboundMain` owns the debug-only `TestBridgeAdapter`, starts it only when a deliberate environment gate is set, and polls it on the Godot main thread. The Python runner remains an external inbound test adapter: it uses LiteLLM's OpenAI Responses endpoint to evaluate PNGs and never sends generated content back into the child-facing game.

**Tech Stack:** Godot 4/GDScript, Python 3 standard library, LiteLLM OpenAI-compatible Responses API, existing HTTP test bridge.

**Spec:** User-approved QA repair request in this session.

## Global Constraints

- The bridge remains disabled by default, binds only `127.0.0.1`, and runs only under an explicit debug environment flag.
- No domain logic depends on the bridge or the vision provider.
- AI receives only test screenshots and prompt text; its output is stored as QA evidence and never rendered into kid/parent UI.
- LiteLLM credentials are read from environment and never logged, committed, or placed in evidence artifacts.
- Preserve the existing Anthropic runner path for users who explicitly configure it.

---

### Task 1: Wire and guard the debug bridge

**Files:**
- Modify: `src/adapters/inbound/main.gd`
- Modify: `src/adapters/outbound/test_bridge_adapter.gd`
- Test: `tests/adapters/outbound/test_test_bridge_adapter.gd`

**Interfaces:**
- Consumes: `FeatureFlagService.is_enabled(feature_key: String) -> bool` and `TestBridgeAdapter.start() -> bool`.
- Produces: a live adapter that is polled each frame only after `start()` succeeds.

- [ ] **Step 1: Write the failing test**

Create a bridge adapter test that enables `debug_test_bridge`, starts the adapter on port `0`, and asserts `inject_input({"type": "action", "action_name": "ui_accept", "pressed": true})` returns `true`.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . --script tests/adapters/outbound/test_test_bridge_adapter.gd`

Expected: FAIL because `TestBridgeAdapter.inject_input()` has no `action` branch.

- [ ] **Step 3: Write minimal implementation**

In `TestBridgeAdapter.inject_input()`, construct and submit an `InputEventAction` for the `action` payload. In `InboundMain`, create/start the adapter only when `CHOYCE_DEBUG_TEST_BRIDGE=1` and the feature flag is enabled, add it to the tree on success, poll it in `_process`, and stop/free it during teardown.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . --script tests/adapters/outbound/test_test_bridge_adapter.gd`

Expected: PASS and no bridge starts unless both debug gates are set.

- [ ] **Step 5: Commit**

```bash
git add src/adapters/inbound/main.gd src/adapters/outbound/test_bridge_adapter.gd tests/adapters/outbound/test_test_bridge_adapter.gd
git commit -m "fix: wire debug-only test bridge"
```

### Task 2: Add a LiteLLM Responses vision backend

**Files:**
- Modify: `scripts/testing/ai_vision_runner.py`
- Modify: `scripts/ci/run-ai-vision-tests.sh`
- Test: `tests/scripts/test_ai_vision_runner.py`

**Interfaces:**
- Consumes: `LITELLM_BASE_URL`, `LITELLM_API_KEY`, and a selected model such as `opencode/gpt-5.6`.
- Produces: `VisionAsserter.assert_screenshot()` returning `(passed, confidence, reasoning)` from an OpenAI Responses API JSON result.

- [ ] **Step 1: Write the failing test**

Add a Python test using a local HTTP fixture that returns an OpenAI Responses payload containing `output_text`; assert the LiteLLM backend reads it and parses the model's JSON verdict.

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/scripts/test_ai_vision_runner.py`

Expected: FAIL because no LiteLLM backend or Responses parser exists.

- [ ] **Step 3: Write minimal implementation**

Add `--vision-provider anthropic|litellm`, `--vision-model`, and `--litellm-base-url` arguments. The LiteLLM backend posts `input_text` plus `input_image` to `/v1/responses`, extracts `output_text`, and uses the existing JSON verdict parser. The CI wrapper accepts the LiteLLM environment variables and forwards this configuration.

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/scripts/test_ai_vision_runner.py`

Expected: PASS without live network credentials.

- [ ] **Step 5: Commit**

```bash
git add scripts/testing/ai_vision_runner.py scripts/ci/run-ai-vision-tests.sh tests/scripts/test_ai_vision_runner.py
git commit -m "feat: support LiteLLM vision QA"
```

### Task 3: Verify the live debug route

**Files:**
- Test only: existing scenario YAML under `tests/ai-scenarios/`

**Interfaces:**
- Consumes: `CHOYCE_DEBUG_TEST_BRIDGE=1`, `CHOYCE_FEATURE_OVERRIDES=debug_test_bridge=true`, Tailnet LiteLLM configuration, and the debug bridge HTTP endpoints.
- Produces: screenshot and JSON evidence under `.ai/manual-qa/`.

- [ ] **Step 1: Run the bridge health smoke test**

Launch Godot with the two debug gates and a non-conflicting port, then assert `GET /health` returns `200` before sending a named input action.

- [ ] **Step 2: Run one visual scenario**

Run `KF-001-first-playable-loop.yaml` with `--vision-provider litellm --vision-model opencode/gpt-5.6` and preserve generated PNG and verdict JSON artifacts.

- [ ] **Step 3: Inspect the evidence**

Confirm the response includes a non-empty visual verdict and that neither request headers nor credentials appear in the JSON evidence.

- [ ] **Step 4: Run regressions**

Run: `godot --headless --path . --script tests/play/run_play_observation.gd` and the new bridge test.

- [ ] **Step 5: Commit**

```bash
git add .ai/manual-qa
git commit -m "test: capture LiteLLM visual QA evidence"
```

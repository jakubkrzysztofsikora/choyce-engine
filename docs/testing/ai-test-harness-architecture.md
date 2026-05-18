# AI Test Agent Harness — Architecture (TASK-061)

## Overview

This document defines the architecture for an AI-agent-driven testing system that allows Claude and other
LLM agents to exercise the choyce-engine Godot 4 application in a way equivalent to a human manual tester
— but reproducible, evidence-capturing, and CI-integrable.

## Design Goals

1. **Hexagonal purity** — The test bridge is an outbound adapter behind a declared port. No test logic
   leaks into the domain layer.
2. **Production safety** — The bridge is disabled by default and only activates under a debug feature flag.
3. **Dual assertion strategy** — Hard assertions on structured JSON state (reliable), soft assertions on
   vision model screenshots (flagged for human review when confidence < 0.9).
4. **Traceability** — Every scenario step records requirement IDs, expected state, actual state, and
   screenshot paths as structured evidence compatible with `.ai/manual-qa/` folder conventions.
5. **CI integration** — Runs alongside existing quality gate scripts via `scripts/ci/run-ai-vision-tests.sh`.

---

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  AI Test Orchestrator                                           │
│  (scripts/testing/ai_vision_runner.py)                         │
│  • Loads scenario YAML from tests/ai-scenarios/               │
│  • Drives test loop: setup → execute → observe → assert        │
│  • Uses TITAN-pattern reflective reasoning (retry on stall)    │
└─────────┬────────────────────────────┬────────────────────────┘
          │                            │
          ▼                            ▼
┌──────────────────┐       ┌───────────────────────┐
│  GoPeak MCP      │       │  gdGSI WebSocket       │
│  (input sim,     │       │  (JSON state deltas,   │
│   screenshots,   │       │   section-based API)   │
│   DAP debugger)  │       └───────────┬───────────┘
└──────────┬───────┘                   │
           │                           │
           ▼                           ▼
┌────────────────────────────────────────────────────────────────┐
│  Godot 4 Runtime                                               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  TestBridgeAdapter (outbound adapter, debug-flag-gated)  │  │
│  │  implements TestBridgePort                               │  │
│  │  • HTTP server: GET /state, GET /screenshot, POST /input │  │
│  │  • gdGSI integration: pushes domain event state deltas   │  │
│  └──────────────────────────────────────────────────────────┘  │
│  Application services, domain model, inbound adapters          │
└────────────────────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────────┐
│  Assertion Layer                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Hard gates: gdGSI JSON field assertions (Python)   │    │
│  │  Soft gates: Claude vision API screenshot check     │    │
│  │              confidence ≥ 0.9 → auto-pass           │    │
│  │              confidence < 0.9 → human review queue  │    │
│  └─────────────────────────────────────────────────────┘    │
│  Evidence output: JSON + PNG → .ai/manual-qa/TASK-XXX/      │
└──────────────────────────────────────────────────────────────┘
```

---

## Port Contract: TestBridgePort

**File**: `src/ports/outbound/test_bridge_port.gd`

```gdscript
class_name TestBridgePort
extends RefCounted

## Outbound port for AI test agent state inspection.
## Production adapters return empty/null; debug adapter is wired by feature flag.

func get_game_state() -> Dictionary:
    return {}

func capture_screenshot() -> PackedByteArray:
    return PackedByteArray()

func inject_input(p_event: Dictionary) -> bool:
    return false

func set_state_section(p_section: String, p_data: Dictionary) -> void:
    pass
```

### Adapter implementations

| Adapter | Context | Notes |
|---|---|---|
| `TestBridgeAdapter` | debug mode only | HTTP server + gdGSI integration |
| `NullTestBridgeAdapter` | production | All methods return safe no-ops |

---

## Scenario DSL

Scenarios are defined as YAML files in `tests/ai-scenarios/`. They are consumed by the Python runner.

### File layout

```
tests/ai-scenarios/
  kid-flows/
    KF-001-first-playable-loop.yaml
    KF-002-ai-hint-comprehension.yaml
    KF-003-moderation-blocks.yaml
    KF-004-voice-to-intent.yaml
  parent-flows/
    PF-001-dashboard-controls.yaml
    PF-002-approval-gates.yaml
    PF-003-rbac-enforcement.yaml
  safety-compliance/
    SC-001-coppa-lifecycle.yaml
    SC-002-consent-revocation.yaml
    SC-003-jailbreak-attempts.yaml
```

### Scenario schema

```yaml
id: KF-001
title: First Playable Loop
requirement_ids: [UX-ONBOARD-01, FUNC-PLAY-01, UX-LANG-01]
tier: [1, 2]
hardware_profile: any
timeout_seconds: 900       # 15 minutes
steps:
  - id: step-1
    action: navigate_to
    target: create_shell
    description: Child opens Create mode from main menu

  - id: step-2
    action: assert_visual
    prompt_pl: "Czy widoczny jest tryb Tworzenia z polskimi etykietami?"
    prompt_en: "Is the Create mode shell visible with Polish-language labels?"
    confidence_threshold: 0.9

  - id: step-3
    action: assert_state
    section: session
    field: current_shell
    expected: create

  - id: step-4
    action: input
    type: mouse_click
    target_description: "Nowe Stworzenie button (start creation)"

  - id: step-5
    action: assert_visual
    prompt_pl: "Czy płótno budowania jest widoczne z kontrolkami dotykowymi?"
    prompt_en: "Is the build canvas visible with touch-friendly controls?"
    confidence_threshold: 0.85
```

### Step action types

| Action | Description |
|---|---|
| `navigate_to` | Drive inbound adapter navigation |
| `assert_visual` | Screenshot → Claude vision API assertion |
| `assert_state` | gdGSI JSON field comparison |
| `input` | Mouse click / key press / gamepad button via GoPeak MCP |
| `wait_for_event` | Block until gdGSI state section receives expected field |
| `set_state` | Inject known state via debug adapter |
| `capture_evidence` | Force screenshot + state snapshot into evidence bundle |

---

## TITAN Reflective Reasoning Pattern

The Python runner implements the TITAN pattern from arXiv:2509.22170 for robust scenario execution:

1. **Perception Abstraction**: gdGSI state deltas are normalized to discrete enum values before
   Claude sees them (e.g., `moderation_result: "BLOCKED"` not raw bitmask).
2. **Action Optimization**: Each step provides `description` and `target_description` so Claude
   filters to ≤5 candidate actions from scene tree inspection.
3. **Reflective Reasoning**: If 3 consecutive steps produce no gdGSI state change, the runner
   triggers a reflection prompt and attempts an alternative sub-step sequence.
4. **Issue Diagnosis**: Crash monitor (Godot exit code ≠ 0), task status monitor (step timeout),
   and visual inspection (screenshot anomaly via Claude).

---

## Evidence Bundle Format

Each executed scenario produces a folder under `.ai/manual-qa/TASK-XXX/evidence/`:

```
TASK-059/evidence/
  KF-001-first-playable-loop/
    run-2026-03-06T19-32-00Z/
      manifest.json        ← scenario metadata, git SHA, hardware tier
      step-01.png          ← screenshot at step 1
      step-01-verdict.json ← {pass: true, confidence: 0.97, reasoning: "..."}
      step-02.png
      step-02-verdict.json
      ...
      summary.json         ← rollup: pass/fail per step, overall verdict
```

### `summary.json` schema

```json
{
  "scenario_id": "KF-001",
  "run_id": "2026-03-06T19-32-00Z",
  "commit_sha": "3b04185",
  "hardware_tier": 1,
  "overall_verdict": "PASS",
  "steps_total": 8,
  "steps_passed": 8,
  "steps_flagged_for_review": 0,
  "steps_failed": 0,
  "duration_seconds": 423,
  "requirement_ids": ["UX-ONBOARD-01", "FUNC-PLAY-01", "UX-LANG-01"]
}
```

---

## CI Integration

The AI vision test pipeline is invoked via:

```bash
./scripts/ci/run-ai-vision-tests.sh [--scenario-dir tests/ai-scenarios/kid-flows] \
                                    [--task TASK-059] \
                                    [--tier 1] \
                                    [--headless]
```

### Headless CI setup (Linux)

```bash
# Start virtual display
Xvfb :99 -screen 0 1920x1080x24 &
export DISPLAY=:99

# Two-phase Godot warm-up
godot --headless --import --quit

# Launch with display for screenshot capture
DISPLAY=:99 godot --path . --debug-bridge-port 9876 &
GODOT_PID=$!

# Run scenarios
python3 scripts/testing/ai_vision_runner.py \
  --bridge-url http://localhost:9876 \
  --scenarios tests/ai-scenarios/ \
  --output .ai/manual-qa/TASK-059/evidence/

kill $GODOT_PID
```

### macOS (native display)

```bash
godot --path . --debug-bridge-port 9876 &
GODOT_PID=$!
sleep 3  # allow Godot to initialize

python3 scripts/testing/ai_vision_runner.py \
  --bridge-url http://localhost:9876 \
  --scenarios tests/ai-scenarios/ \
  --output .ai/manual-qa/TASK-059/evidence/

kill $GODOT_PID
```

---

## Safety Constraints

- The `TestBridgeAdapter` MUST NOT be compiled into production exports. It is gated by
  `FeatureFlagService.is_enabled("debug_test_bridge")`, which resolves to `false` in all
  non-debug deployment profiles (see TASK-040).
- The HTTP server binds to `127.0.0.1` only — never `0.0.0.0`.
- No child PII is logged by the bridge. State sections must use anonymized session IDs only.
- Abuse scenarios (jailbreak, consent bypass) run in an isolated test profile with no real
  moderation model connections — stubs only.

---

## Requirement Traceability

| Scenario category | Requirement IDs covered |
|---|---|
| Kid first-playable loop | UX-ONBOARD-01, FUNC-PLAY-01, UX-LANG-01 |
| AI hint comprehension | FUNC-AI-03, UX-HINT-01, UX-LANG-01 |
| Moderation blocks | SAFE-MOD-01, SAFE-MOD-02, SAFE-VOICE-01 |
| Voice to intent | FUNC-VOICE-01, SAFE-VOICE-01, UX-LANG-01 |
| Parent dashboard | FUNC-PARENT-01, SAFE-RBAC-01, UX-PARENT-01 |
| Approval gates | FUNC-PUBLISH-02, SAFE-RBAC-01 |
| RBAC enforcement | SAFE-RBAC-01, SAFE-RBAC-02 |
| COPPA lifecycle | COMP-COPPA-01, COMP-GDPR-01 |
| Consent revocation | COMP-COPPA-02, SAFE-CONSENT-01 |
| Jailbreak attempts | SAFE-MOD-03, SAFE-VOICE-02, SAFE-RBAC-02 |

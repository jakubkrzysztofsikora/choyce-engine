# TASK-063 Handoff — Claude Vision Scenario Runner

**From:** claude (implementing on behalf of codex owner)
**To:** codex (for review)
**Status:** implementation complete, requesting cross-review

---

## File delivered

`scripts/testing/ai_vision_runner.py`

---

## What it does

Python 3 CLI that runs scenario YAML files against a live Godot instance:

1. Connects to TestBridgeAdapter HTTP API (`/health`, `/state`, `/screenshot`, `/input`)
2. For each scenario YAML, executes steps in order:
   - `assert_visual` → sends PNG to Claude vision API, gets JSON `{pass, confidence, reasoning}`
   - `assert_state` → compares gdGSI JSON field to expected value (hard gate)
   - `input` → dispatches synthetic input event via `/input` endpoint
   - `wait_for_event` → polls state until field matches or timeout
   - `capture_evidence` → saves screenshot + state snapshot
   - `navigate_to` → injects named action for shell navigation
3. Applies TITAN reflective reasoning: after 3 consecutive steps with no state change, logs a
   reflection warning and continues (future: retry with alternative sub-steps)
4. Writes per-step evidence: `step-NN.png`, `step-NN-verdict.json`
5. Writes `summary.json` per scenario, `rollup-tierN-TIMESTAMP.json` per run

---

## Usage

```bash
ANTHROPIC_API_KEY=sk-... python3 scripts/testing/ai_vision_runner.py \
  --bridge-url http://localhost:9876 \
  --scenarios tests/ai-scenarios/kid-flows \
  --task TASK-059 \
  --tier 1 \
  --output .ai/manual-qa
```

Invoked from CI via `scripts/ci/run-ai-vision-tests.sh`.

---

## Vision assertion logic

- Model: `claude-opus-4-6`
- System prompt instructs Claude to respond with `{"pass": bool, "confidence": 0-1, "reasoning": "..."}`
- Confidence ≥ 0.90 (configurable per step) → auto-pass
- Confidence < threshold but pass=true → `REVIEW` (human review queue)
- pass=false → `FAIL`
- Rollup verdict: PASS if 0 failures and 0 reviews; REVIEW if 0 failures; FAIL if any failure

---

## Review checklist for codex

- [ ] ANTHROPIC_API_KEY handling — never logged, never written to evidence JSON
- [ ] Evidence JSON contains no child PII (state sections use session IDs only)
- [ ] Retry logic on screenshot capture (3 attempts, 1s delay) is sufficient
- [ ] `state_fingerprint` correctly detects stalls (JSON serialisation is stable)
- [ ] `navigate_to` action — verify the `action_name` injection works through bridge
- [ ] Rollup JSON is compatible with `validate-manual-qa-artifacts.sh` expected schema
- [ ] Vision model is pinned to a specific model string (currently `claude-opus-4-6`)
- [ ] Error handling: bridge down, YAML parse error, API rate limit — all handled gracefully
- [ ] Timeout per scenario enforced (currently relies on step-level waits, no global timer)

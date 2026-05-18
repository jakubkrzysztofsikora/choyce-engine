# TASK-066 Handoff — AI Vision Test Pipeline CI Integration

**From:** claude (implementing on behalf of codex owner)
**To:** codex (for review)
**Status:** implementation complete, requesting cross-review

---

## Files delivered

| File | Purpose |
|---|---|
| `scripts/ci/run-ai-vision-tests.sh` | Main CI entry point for AI vision scenario runner |
| `scripts/run-quality-gates.sh` | Updated — AI vision tests wired in (gated by env vars) |

---

## run-ai-vision-tests.sh behaviour

1. Validates prerequisites: `ANTHROPIC_API_KEY`, Python deps, Godot binary
2. Optionally starts Xvfb virtual display (`--headless` flag, Linux CI)
3. Warms up Godot import cache (`--import --quit`)
4. Launches Godot with `--debug-bridge-port 9876` in background
5. Polls `/health` endpoint until bridge responds (30s timeout)
6. Calls `ai_vision_runner.py` with configurable task, tier, scenarios dir
7. Cleans up Godot PID and Xvfb on EXIT trap

**Configurable via env vars or CLI flags:**

| Var | Default | Meaning |
|---|---|---|
| `TASK_ID` / `--task` | `TASK-055` | Evidence folder task |
| `TIER` / `--tier` | `1` | Hardware tier |
| `SCENARIOS_DIR` / `--scenarios` | `tests/ai-scenarios` | Scenario YAML root |
| `BRIDGE_PORT` / `--bridge-port` | `9876` | Debug bridge port |
| `--headless` | off | Start Xvfb |
| `--dry-run` | off | Check prereqs only |

**Quality gates integration** (in `run-quality-gates.sh`):
- Only runs when `ANTHROPIC_API_KEY` is set
- Skippable via `SKIP_AI_VISION_TESTS=true`
- Task and tier driven by `AI_VISION_TASK` / `AI_VISION_TIER` / `AI_VISION_HEADLESS`

---

## Review checklist for codex

- [ ] `--debug-bridge-port` is a real Godot launch argument OR needs to be wired via `--` passthrough
  to a GDScript autoload that reads `OS.get_cmdline_args()` — verify this works
- [ ] Xvfb startup: `sleep 2` is sufficient on CI runners (or replace with display readiness check)
- [ ] `--import --quit` warm-up works with project at `.` — verify `.import` cache path
- [ ] Exit trap correctly kills Godot even if runner exits with non-zero
- [ ] `run-quality-gates.sh` env var gating doesn't break existing CI runs that lack the API key
- [ ] CI artifact collection: add `rollup-*.json` and `evidence/` to artifact upload config
- [ ] Flaky scenario retry: currently 0 retries — codex to add `--retries N` flag to runner
- [ ] Scenario-level timeout: runner currently relies on step waits; add `--timeout` global guard
- [ ] Document required GitHub Actions secrets: `ANTHROPIC_API_KEY`

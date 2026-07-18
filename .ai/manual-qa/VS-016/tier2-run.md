# VS-016 Tier-2 Run

- Date: 2026-07-18
- Tester: Copilot CLI (junior coder mode)
- Hardware tier: Tier-2
- Device spec: N/A (prerequisite probe only; live capture blocked)
- OS version: macOS (host not separately captured)
- Build/commit: 127d462807d15f7199121fcad8556ef7e13d9d8d
- Start time (UTC): 2026-07-18T09:12:08Z
- End time (UTC): 2026-07-18T09:16:00Z

## Capture readiness

<a id="tier2-capture-readiness"></a>
### 1. Runner prerequisites
- Expected: the AI vision runner can launch Godot and collect rendered screenshots.
- Observed: `ANTHROPIC_API_KEY` is unset, and `./scripts/ci/run-ai-vision-tests.sh --task VS-016 --tier 2 --dry-run` exits with `ERROR: ANTHROPIC_API_KEY not set`.
- Pass/Fail: **BLOCKED**

## Visual acceptance checks

<a id="tier2-launcher-capture"></a>
### 2. Launcher
- Expected: launcher screenshot retained.
- Observed: not captured because the vision runner stopped before launch.
- Pass/Fail: **BLOCKED**

<a id="tier2-spawn-capture"></a>
### 3. Spawn
- Expected: spawn screenshot retained.
- Observed: not captured because the vision runner stopped before launch.
- Pass/Fail: **BLOCKED**

<a id="tier2-guide-capture"></a>
### 4. Guide interaction
- Expected: guide interaction screenshot retained.
- Observed: not captured because the vision runner stopped before launch.
- Pass/Fail: **BLOCKED**

<a id="tier2-transition-capture"></a>
### 5. Region transition
- Expected: region transition screenshot retained.
- Observed: not captured because the vision runner stopped before launch.
- Pass/Fail: **BLOCKED**

<a id="tier2-combat-capture"></a>
### 6. Combat
- Expected: combat screenshot retained.
- Observed: not captured because the vision runner stopped before launch.
- Pass/Fail: **BLOCKED**

## Performance

<a id="tier2-performance-capture"></a>
### 7. Tier-2 performance
- Expected: Tier-2 FPS, frame-time, memory, draw-call, and vertex measurements are recorded.
- Observed: no live performance sampling was possible because rendered capture never started.
- Pass/Fail: **BLOCKED**

## Findings

- <a id="f-016-01-tier2"></a>F-016-01 — HIGH — Live rendered evidence is blocked in this environment because `ANTHROPIC_API_KEY` is unset, so VS-016 cannot produce screenshots or performance measurements here.

## Risk Summary

- Overall release risk: HIGH
- Recommended action: unblock the vision runner, capture the required screenshots and performance measurements, then re-run the manual QA validation.

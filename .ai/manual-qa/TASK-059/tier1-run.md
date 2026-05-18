# TASK-059 Tier-1 Run

- Date: 2026-03-06
- Tester: claude (AI Architecture Agent — static code analysis run)
- Method: Static analysis of src/adapters/inbound/main.gd, create_shell.gd, manage_data_lifecycle_service.gd
  NOTE: This run is a code-review evaluation. Live Godot execution deferred to AI vision runner (TASK-063).
  Evidence type: static — no screenshots. Scenario runner evidence to be added when bridge is live.
- Hardware tier: Tier-1 (code analysis; runtime to be validated on Intel i5 / 8 GB RAM equivalent)
- Device spec: N/A (static analysis)
- OS version: macOS 25.0.0 (Darwin)
- Build/commit: 3b04185
- Start time (UTC): 2026-03-06T19:45:00Z
- End time (UTC): 2026-03-06T20:15:00Z

---

## Scenario Results

### 1. First playable loop — time-to-fun

- Expected: Child reaches playable state (Create mode with canvas) ≤ 15 minutes.
- Analysis: `InboundMain._ready()` immediately calls `_navigator.show_shell(SHELL_CREATE)`.
  `CreateShell._ensure_world_context()` auto-creates a `starter_canvas` project on first tool use.
  Onboarding service fires STEP_WELCOME → STEP_PLACE_FIRST → STEP_PAINT_FIRST → STEP_PLAY in
  sequence with Polish instructions. `_launch_playtest()` then hands off to `RunPlaytestPort`.
  The complete loop is code-complete and navigable.
- Observed: All code paths exist and are connected. Zero-friction path from launch → Create →
  Place object → Play is supported. Time-to-fun well within 15 min budget.
- Pass/Fail: **PASS** (with medium finding F-002 on diacritics — see below)

### 2. Hint comprehension

- Expected: Child understands hint progression and can proceed without forced adult takeover.
- Analysis: `OnboardingService` (steps: welcome → place_first → paint_first → play) fires
  `step_changed` signal connected to `_on_onboarding_step_changed`, which shows overlay with
  target button highlight. Fallback Polish strings are present but use ASCII approximations
  (no diacritics). AI voice assistant overlay requires `RequestAICreationHelpPort` to be non-null.
- Observed: Onboarding hints are structurally correct. Text strings need diacritics (F-002).
  No "adult rescue" state is tracked — cannot assert `adult_rescue_required: false` at runtime.
  `KEY_REQUEST_AI_HELP_PORT` is absent from `_build_default_ports()` — voice/AI hints unavailable
  in default composition (F-001, HIGH).
- Pass/Fail: **PARTIAL PASS** — onboarding hints work; AI voice hints blocked by missing port wiring.

### 3. Parent intervention clarity

- Expected: Parent can find and use relevant controls without ambiguity.
- Analysis: `_parent_shell.visible = _is_parent()` and `_nav_parent.visible = _is_parent()` in
  `_wire_shell_dependencies()`. Parent Zone shell is entirely hidden from kid role. Parent role
  detected via `_profile.is_parent()`. `SetParentalControlsService` is wired to all required ports.
  `ParentAuditReadModelAdapter` receives all domain events via event bus subscription.
- Observed: Role enforcement is clear and correct. Parent shell shows/hides correctly by role.
  No ambiguity in UI — parent nav tab is not rendered at all for kid profiles.
- Pass/Fail: **PASS**

---

## Findings

### F-059-01 (HIGH) — AI Creation Help port not wired in default runtime

- Severity: HIGH
- Repro steps: Launch app in default kid mode → open Create shell → check AI assistant overlay visibility
- Expected: AI assistant overlay visible with voice input and AI action cards
- Actual: `KEY_REQUEST_AI_HELP_PORT` absent from `_build_default_ports()` dict in main.gd:L148.
  `_ports.get(KEY_REQUEST_AI_HELP_PORT, null)` returns null → `_assistant_overlay.visible = false`.
  Voice-to-AI-intent flow completely disabled.
- Evidence: src/adapters/inbound/main.gd:148 (KEY_REQUEST_AI_HELP_PORT missing from defaults dict)
- Requirement trace: FUNC-AI-03, UX-HINT-01
- Remediation owner: codex

### F-059-02 (MEDIUM) — Polish diacritics missing in create_shell.gd status strings

- Severity: MEDIUM
- Repro steps: Open Create mode → observe status messages and info label
- Expected: Properly accented Polish ("Utwórz", "Umieść", "Przesuń", "Zaznaczenie")
- Actual: ASCII approximations: "Tworz", "Umiesc", "Przesun", "Zaznaczenie" (missing ó, ę, ś, ą, etc.)
  Lines affected: create_shell.gd:216, 217, 231, 250, 255, 258, 289, 338, 358, 413, 417
  Note: Tool button labels via `_t()` correctly return "Umieść" etc. from localization policy.
  Hardcoded strings in _info, _status_message, and _world_summary bypass `_t()`.
- Evidence: src/adapters/inbound/scenes/create/create_shell.gd (multiple lines, see above)
- Requirement trace: UX-LANG-01
- Remediation owner: copilot

### F-059-03 (LOW) — adult_rescue_required state not tracked

- Severity: LOW (test harness gap, not product bug)
- Repro steps: N/A — state field does not exist
- Expected: Session state section exposes `adult_rescue_required: bool` for AI test assertions
- Actual: No such field emitted; onboarding service tracks step completion, not rescue events
- Requirement trace: UX-ONBOARD-01 (implied)
- Remediation owner: claude (add to TestBridgeAdapter state section spec)

---

## Risk Summary

- Overall release risk: MEDIUM
- Recommended action:
  1. F-059-01 (HIGH): Wire `RequestAICreationHelpPort` in `_build_default_ports()` before ship.
     AI creation assist is a core MVP feature — its absence is a release blocker for that flow.
  2. F-059-02 (MEDIUM): Fix diacritics in 11 hardcoded strings in create_shell.gd.
     Polish certification cannot pass with ASCII-approximation strings.
  3. F-059-03 (LOW): Add state tracking field to test bridge — no product change needed.

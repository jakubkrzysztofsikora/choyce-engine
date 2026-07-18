# TASK-055 Tier-1 Run

- Date: 2026-07-18
- Tester: claude (AI Architecture Agent — static code analysis; AI vision runner evidence deferred)
- Hardware tier: Tier-1
- Device spec: N/A (static analysis — commit 9be15cbd2eebb6263033f1b5240eb06de2024374)
- OS version: macOS 15.0.0
- Build/commit: 9be15cbd2eebb6263033f1b5240eb06de2024374
- Start time (UTC): 2026-07-18T04:00:00Z
- End time (UTC): 2026-07-18T04:30:00Z

## Scenario Results
1. Child quick-start loop
- Expected: first playable loop completed in <= 15 minutes.
- Observed: Create shell auto-creates starter_canvas on first tool press. Onboarding service
  fires Polish step instructions. GoPlay button launches playtest session and navigates to Play shell.
  All code paths connected. Time-to-fun well within 15 min budget.
- Pass/Fail: **PASS**

2. Co-creation with AI hints
- Expected: child can progress using hints without unsafe/off-topic outputs.
- Observed: KEY_REQUEST_AI_HELP_PORT is NOT in _build_default_ports() (main.gd:148).
  VoiceAssistantOverlay.visible = false when port is null — AI assist entirely disabled.
  Onboarding-based step hints (non-AI) still work. Moderation enforced via LocalModerationAdapter
  when AI port is wired. This is a HIGH severity blocker for the AI co-creation MVP flow.
- Pass/Fail: **FAIL** (F-055-01 — AI port missing from default runtime composition)

3. Co-op playtest
- Expected: co-play remains stable and understandable for kid+parent pair.
- Observed: _launch_playtest(local_coop=true) creates guest profile ("Gosc") and passes both
  profiles to RunPlaytestPort. Session.SessionMode.CO_OP mode set correctly. Info label updated:
  "Test uruchomiony: kooperacja". Code path is complete.
  Note: "kooperacja" hardcoded without full localization key — bypass of _t().
- Pass/Fail: **PASS** (minor finding F-055-02 on hardcoded co-op label)

4. Private family sharing
- Expected: family-only sharing works; outsider visibility remains blocked.
- Observed: PublishToFamilyLibraryService enforces moderation + parent approval via event bus.
  ReviewPublishRequestService checks publishing_policy. UnpublishWorldService available.
  HOWEVER: InMemoryPublishStore resets on restart — share state not durable.
  Visibility enforcement at policy level is code-complete; persistence is not.
- Pass/Fail: **CONDITIONAL PASS** (F-055-03 — in-memory publish store not persistent)

## Findings
- ID: F-055-01
  - Severity: HIGH
  - Repro steps: Launch default app → Create shell → look for AI assistant overlay
  - Expected: AI voice/text creation assistant visible and functional
  - Actual: KEY_REQUEST_AI_HELP_PORT not in _build_default_ports() → overlay hidden
  - Evidence: src/adapters/inbound/main.gd:148 (dict missing KEY_REQUEST_AI_HELP_PORT key)
  - Requirement trace: FUNC-AI-03, UX-HINT-01

- ID: F-055-02
  - Severity: LOW
  - Repro steps: Launch co-op playtest → observe info label text
  - Expected: Localized string via _t() for co-op label
  - Actual: Hardcoded "kooperacja" / "solo" strings at create_shell.gd:358
  - Evidence: src/adapters/inbound/scenes/create/create_shell.gd:358
  - Requirement trace: UX-LANG-01

- ID: F-055-03
  - Severity: MEDIUM
  - Repro steps: Publish world → restart app → open Library shell
  - Expected: Published world visible in family library after restart
  - Actual: InMemoryPublishStore loses all state on restart (main.gd:133)
  - Evidence: src/adapters/inbound/main.gd:133
  - Requirement trace: FUNC-PUBLISH-02, FUNC-LIBRARY-01

## Risk Summary
- Overall release risk: HIGH
- Recommended action:
  1. F-055-01 (HIGH, RELEASE BLOCKER): Wire RequestAICreationHelpPort in _build_default_ports().
     AI co-creation is a core MVP differentiator — must be resolved before ship.
  2. F-055-03 (MEDIUM): Replace InMemoryPublishStore with FilesystemPublishStore in production.
  3. F-055-02 (LOW): Move co-op label through _t() localization function.
  4. Also inherit F-059-02 (diacritics) — same evidence base.

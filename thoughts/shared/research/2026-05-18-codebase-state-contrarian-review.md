---
date: 2026-05-18
commit: 3b0418558329404463541ecd1ed9329c8b9c73bf
branch: main
tags: [codebase-state, contrarian-review, hexagonal, safety, coppa, ux, performance, batch-review]
status: complete
reviewers:
  - plans-vs-reality (dev:code-reviewer)
  - requirements-coverage (pokayokay:yokay-auditor)
  - good-practices (pokayokay:yokay-reviewer)
  - utility-usability (dev:codebase-analyzer)
  - performance (dev:code-reviewer)
---

# Research: Codebase State — Batch Contrarian Review

## Summary

Five parallel contrarian reviewers audited the choyce-engine codebase (commit `3b04185`, branch `main`) against plans/backlog, requirements docs, hexagonal good-practices, kid+parent usability, and performance. The codebase has strong **domain/application discipline** (clean RefCounted boundaries, correct failsafe defaults in moderation) but suffers a recurring **composition-root gap**: multiple services marked `status: done` in `.ai/tasks/backlog.yaml` are never wired in `src/adapters/inbound/main.gd:138-217`, leaving encrypted parental policy storage, COPPA data lifecycle, voice input moderation, progression services, and persistent stores as dead code. Two **release blockers** (COPPA panel L1, voice moderation L1) and one **certification blocker** (Polish strings bypassing `_t()`) sit on top of structural issues (unbounded caches, synchronous Ollama on main thread, O(N²) moderation tokenization, fake performance benchmarks).

## Files Involved

### Composition Root / Inbound Wiring
| File | Layer | Purpose / Finding |
|------|-------|-------------------|
| `src/adapters/inbound/main.gd:138-217` | Adapter (inbound) | `_build_default_ports()` — single source of truth for wiring. Missing: `ManageDataLifecycleService`, `VoiceInputModerationService`, `EncryptedParentalPolicyStore`, progression/clone/remix services. Uses `InMemoryPublishStore`, `InMemoryParentalPolicyStore`, in-memory `LocalConsentStore` instead of persistent variants. |
| `src/adapters/inbound/scenes/create/create_shell.gd:231-770` | Adapter (UI) | 30+ hardcoded Polish strings bypassing `_t()` (lines 231, 232, 233, 246, 253, 305, 310, 314, 329, 344, 373, 377, 381, 393, 415-418, 455, 469, 473, 478, 509, 561-568, 575-582, 701, 717, 770-774, 817). |
| `src/adapters/inbound/scenes/play/play_shell.gd:113-222` | Adapter (UI) | Hardcoded strings + fabricated mock session-end stats (line 184 `"~2 min"`, `randi() % 5` collectibles). |
| `src/adapters/inbound/scenes/parent/parent_zone_shell.gd:80-94, 207` | Adapter (UI) | `_apply_role_guard()` fires at `_ready()` with null profile → entire shell hidden first paint. Playtime summary at line 207 hardcoded mock. |
| `src/adapters/inbound/scenes/library/library_shell.gd:123, 193-197` | Adapter (UI) | RBAC enforced by `disabled` attribute only, not in handler. |
| `src/adapters/inbound/shared/ui/onboarding_overlay.gd:17, 51` | Adapter (UI) | `MOUSE_FILTER_STOP` with no timeout/skip — child can be permanently blocked. Celebration string hardcoded. |
| `src/adapters/inbound/shared/ui/captions_overlay.gd:37, 52-56` | Adapter (UI) | Captions fixed 24px, no high-contrast, no scaling for non-readers. |

### Application Services (Built, Some Unwired)
| File | Wired in main.gd? | Notes |
|------|-------------------|-------|
| `src/application/manage_data_lifecycle_service.gd` | NO | COPPA export/delete — RELEASE BLOCKER (F-060-01). |
| `src/application/voice_input_moderation_service.gd:9,73,118` | NO | Transcript safety gate. Duck-typed intent extractor via `has_method("extract_intent")`. RELEASE BLOCKER. |
| `src/application/clone_world_service.gd`, `remix_world_service.gd`, `manage_progression_service.gd` | NO | TASK-025 / TASK-029 services unreachable. |
| `src/application/approve_ai_patch_service.gd:10,26` | partial | `_pending_actions` unbounded. |
| `src/application/ai_patch_workflow_service.gd:11,30` | partial | `_actions` unbounded. |
| `src/application/visual_asset_generation_service.gd:13-22, 134, 313, 345, 405` | yes | `PHOTOREAL_HUMAN_TERMS` divergent from moderation adapter; non-crypto `.hash()` for IDs. |
| `src/application/feature_flag_service.gd:22` | yes | Calls `OS.get_environment()` directly — framework leakage in application layer. |
| `src/application/deployment_config.gd:25` | yes | Same `OS.get_environment()` leak. |
| `src/application/onboarding_service.gd:7-9` | yes | Godot `signal` declared in application layer — framework leakage. |

### Domain
| File | Finding |
|------|---------|
| `src/domain/gameplay/quest_log.gd:7-10` | Godot `signal` in domain aggregate. |
| `src/domain/**/*.gd` | Otherwise clean — all extend `RefCounted`. |

### Outbound Adapters
| File | Finding |
|------|---------|
| `src/adapters/outbound/ollama_llm_adapter.gd:323-385, 172, 220, 414` | Synchronous HTTP with `OS.delay_msec(1)` busy-wait on main thread. `stream: false`. 30s freeze possible. Non-crypto `.hash()` for IDs. |
| `src/adapters/outbound/in_memory_audit_ledger.gd:18-30, 41-58, 62-81` | Unbounded growth, O(N) scan on `get_records`, O(N) re-hash on `verify_integrity`. |
| `src/adapters/outbound/filesystem_audit_ledger.gd` | Default in prod (`main.gd:152`). Disk I/O per append — worse than in-memory variant. |
| `src/adapters/outbound/local_moderation_adapter.gd:90-105, 164-186` | O(N²) string concat in `_normalize_text`, 19 full-string `.replace()` passes in `_tokenize`. Nested loop categories×terms×words. |
| `src/adapters/outbound/prompt_injection_filter.gd` | 7 English patterns, **zero Polish** — pl-PL first project. Safety gap. |
| `src/adapters/outbound/encrypted_parental_policy_store.gd`, `local_encrypted_storage.gd` | Dead code — built (AES-256-CBC + HMAC) but `main.gd:145` wires `InMemoryParentalPolicyStore`. |

### Tests
| File | Finding |
|------|---------|
| `tests/performance/run_performance_benchmarks.gd:141-215` | "Benchmarks" only exercise `Node3D.new()` + sin/cos. No LLM/moderation/audit/STT scenarios. Budget gates pass regardless of real-path regressions. |

## Data Flow Audit (Inbound → Domain)

Kid voice-help happy path expected:
1. `create_shell.gd:275` receives ports from `main.gd:200`.
2. Tap mic → `LocalSTTAdapter.transcribe()` (`main.gd:213`).
3. **Expected**: transcript → `VoiceInputModerationService.moderate(transcript)` → BLOCK or pass.
4. **Actual**: transcript → directly to AI dispatch / intent extraction. **Step 3 skipped** because `VoiceInputModerationService` never constructed in `_build_default_ports()`. FR-022 is L1 at runtime despite memory claiming TASK-042 done/in_review.

COPPA parent flow expected:
1. Parent opens parent zone → `parent_zone_shell.setup(...)` receives ports.
2. **Expected**: `ManageDataLifecyclePort` in args, panel exposes export+delete buttons.
3. **Actual**: `parent_zone_shell.setup()` has no `manage_data_lifecycle_port` parameter; no panel exists. User cannot reach the feature. F-060-01.

## Existing Patterns

- **Bounded cache reference impl**: `src/adapters/outbound/deterministic_tool_execution_gateway.gd:148` — `MAX_CACHE_ENTRIES = 1000` + `_cache_order` LRU. Pattern to copy for `ApproveAIPatchService` and `AIPatchWorkflowService`.
- **Bounded preview cache**: `src/application/visual_asset_generation_service.gd` — `MAX_PREVIEW_CACHE = 24` with `_preview_order` FIFO. Good template.
- **Crypto hash chain**: `in_memory_audit_ledger.gd` uses `String.sha256_text()` — extend pattern to all ID generation (replace 11 `.hash()` call sites in application layer).
- **Failsafe default**: `local_moderation_adapter.gd:113, 120` returns BLOCK for unknown categories — correct.

## Architecture Notes

- **Hexagonal discipline** holds in `src/domain/` and most of `src/application/` (17+ RefCounted types, no Godot Node imports).
- **Framework leakage** sneaks in via three vectors:
  1. `signal` keyword in domain (`quest_log.gd`) and application (`onboarding_service.gd`).
  2. Direct `OS.get_environment()` in application (`feature_flag_service.gd`, `deployment_config.gd`).
  3. Duck-typing `has_method()` calls for methods that should sit on port contracts (`voice_input_moderation_service.gd:73`, `request_ai_creation_help_service.gd:536-541`, `offline_autosave_service.gd:91-140`, plus prior TASK-018/TASK-041 instances).
- **Composition root is the bottleneck**: every "done" backlog claim must be verified against `_build_default_ports()` because GDScript has no compile-time DI check.

## External Dependencies

- **Ollama** (local LLM, blocking HTTP, no streaming enabled).
- **STT**: `LocalSTTAdapter` wired; `CloudSTTAdapter` placeholder.
- **Godot 4.x** engine — leakage into domain/application as noted.

## Punch List — Severity Ranked

### Release Blockers
1. **Wire `ManageDataLifecycleService`** in `_build_default_ports()`, add `manage_data_lifecycle_port` to `parent_zone_shell.setup()`, add COPPA export/delete panel to `parent_zone_shell.tscn`. (F-060-01)
2. **Wire `VoiceInputModerationService`** before STT port reaches `create_shell.gd`. Gate transcript through moderation before AI dispatch. (FR-022, F-055 family)
3. **Create `IntentExtractorPort`** at `src/ports/outbound/intent_extractor_port.gd`; replace `has_method("extract_intent")` duck-type at `voice_input_moderation_service.gd:73`.

### Certification Blockers
4. **Polish localization through `_t()`**: 30+ hardcoded strings in `create_shell.gd`, `play_shell.gd`, `parent_zone_shell.gd`, `onboarding_overlay.gd`. (F-056-01)
5. **Polish prompt-injection patterns**: add `"ignoruj poprzednie instrukcje"`, `"teraz jesteś"`, `"nowe instrukcje:"`, etc. to `prompt_injection_filter.gd`.

### High (correctness / safety)
6. **Merge term lists**: move `PHOTOREAL_HUMAN_TERMS` from `visual_asset_generation_service.gd` into the moderation adapter category dictionary — single source of truth.
7. **Backlog status drift**: flip TASK-036, TASK-042, TASK-048 from `done` to `in_review`/`blocked` until adapters enter composition root.
8. **Replace `InMemoryPublishStore`** (`main.gd:142`) with filesystem-backed store. (F-055-03)
9. **Replace in-memory `LocalConsentStore`** (`main.gd:138`) with persistent store. (F-060-02)
10. **Wire `EncryptedParentalPolicyStore`** in place of `InMemoryParentalPolicyStore` (`main.gd:145`).

### Medium (performance)
11. **Async Ollama**: switch `ollama_llm_adapter.gd` to `HTTPRequest` node + signals, enable `stream: true`, emit partial tokens. UI cancellable.
12. **Cap moderation tokenization cost**: use `PackedStringArray` accumulator in `_normalize_text`, single-pass tokenize, pre-flatten `{term: category}` dict for O(1) lookup.
13. **Audit ledger bounding**: rolling window cap + actor/event index in `in_memory_audit_ledger.gd` and `filesystem_audit_ledger.gd`; cache verification state.
14. **Defer non-critical adapters** in `_build_default_ports()` via `call_deferred` to keep first frame snappy.
15. **Real performance tests**: replace `Node3D.new()` loops in `tests/performance/run_performance_benchmarks.gd` with adapter-exercising scenarios.

### Medium (architecture)
16. **Bound `_pending_actions` / `_actions`** in `approve_ai_patch_service.gd` and `ai_patch_workflow_service.gd` — copy LRU pattern from `deterministic_tool_execution_gateway.gd:148`.
17. **Extract `EnvironmentPort`** so `feature_flag_service.gd` and `deployment_config.gd` stop calling `OS.get_environment()` directly.
18. **Remove `signal` from domain/application** (`quest_log.gd`, `onboarding_service.gd`) — replace with `DomainEventBus`.
19. **Replace 11 `.hash()` ID call sites** with `String.sha256_text()` (or sha256 + monotonic counter) — collision risk on 32-bit Bernstein.

### Low (cleanup)
20. Remove redundant `has_method` guards in `request_ai_creation_help_service.gd:536-541` and `offline_autosave_service.gd:91, 140` — methods already on port contracts.
21. Disambiguate audit double-source: `event_bus.subscribe_all` + direct ledger writes both feed `parent_audit_read_model_adapter` (`main.gd:152-158`). Pick one.
22. Onboarding overlay needs timeout/skip button (`onboarding_overlay.gd:17`).
23. Captions overlay needs size/contrast options for non-readers (`captions_overlay.gd:37`).
24. Replace fabricated session-end stats (`play_shell.gd:175-184`) with real progression read model.

## Open Questions

- **Status discipline**: who owns flipping `.ai/tasks/backlog.yaml` statuses back from `done` when composition-root wiring is missing? Should a CI gate fail PRs that change `status: done` without adding lines to `_build_default_ports()`?
- **Encrypted vault rollout**: is `EncryptedParentalPolicyStore` dead-code because the encryption key bootstrapping isn't ready, or simply forgotten?
- **STT model contract**: should `IntentExtractorPort` live alongside `SpeechToTextPort`, or be merged into a `VoiceAssistantPort` to keep transcript+intent atomic?
- **Performance budgets**: what are the actual budgets for cold start, Ollama TTFT, moderation latency, audit append? `tests/performance/` measures none of these — until budgets exist, "perf passes" is meaningless.
- **Memory drift**: agent memory (`MEMORY.md`) says F-055-01 / F-059-01 are release blockers, but reviewer-1 confirmed `KEY_REQUEST_AI_HELP_PORT` now wired at `main.gd:200`. Memory should be refreshed; that specific bug may already be fixed.

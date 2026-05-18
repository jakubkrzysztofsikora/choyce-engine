---
date: 2026-05-18
commit: 3b0418558329404463541ecd1ed9329c8b9c73bf
branch: main
ticket: contrarian-review-2026-05-18
status: draft
scope: all 24 findings, phased
ownership: claude orchestrates batch swarm of specialist subagents
migration: greenfield (no in-memory to persistent migration)
translation: bielik (Polish-specialist LLM) via litellm proxy
---

# Plan: Fix All Contrarian Review Findings

## Summary
Phased remediation of 24 findings from `thoughts/shared/research/2026-05-18-codebase-state-contrarian-review.md`. Composition-root wiring gaps, certification-blocking Polish localization, hexagonal leakage, recurring architectural debt (unbounded caches, non-crypto IDs), and performance footguns. Execution model: Claude orchestrates a batch of specialist subagents per phase; Polish UX strings translated by **bielik** (specialized Polish LLM) routed through `http://litellm` proxy.

## Research References
- `thoughts/shared/research/2026-05-18-codebase-state-contrarian-review.md`
- `.ai/tasks/backlog.yaml` — backlog drift (TASK-036, 042, 048 wrongly `done`)
- `docs/requirements/{architecture,functionality,ui-ux}-requirements.md`
- `.ai/manual-qa/` — F-055, F-056, F-059, F-060 series

## Execution Model — Swarm Orchestration

Each phase below names the specialist subagent(s) Claude will dispatch in **batch** (parallel where independent, serial where dependencies). Phases are gated by their own automated + manual verification — never proceed without green.

| Specialist | Agent | Use for |
|---|---|---|
| Composition-root wiring | `pokayokay:yokay-implementer` | edit `src/adapters/inbound/main.gd` `_build_default_ports()` |
| Port + service authoring | `pokayokay:yokay-implementer` | new ports / refactor application services |
| Polish translation | external — **bielik** via `http://litellm` (POST `/v1/chat/completions`, `model: "bielik"`) | translate + check diacritics for every `_t()` key |
| Localization wiring | `pokayokay:yokay-implementer` | move hardcoded strings to `_t(key)` + register keys in localization resource |
| Performance refactor | `dev:codebase-analyzer` (audit) then `pokayokay:yokay-implementer` (edit) | async Ollama, audit ledger bounds, moderation tokenization |
| Verification | `pokayokay:yokay-spec-reviewer` + `pokayokay:yokay-quality-reviewer` + `pokayokay:yokay-test-runner` | per-phase gate |
| Browser/UI verify | `pokayokay:yokay-browser-verifier` | post-phase manual checks |

Bielik usage protocol (every Polish string):
```
POST http://litellm/v1/chat/completions
{
  "model": "bielik",
  "messages": [
    {"role": "system", "content": "Tłumaczysz UI dziecięcego, bezpiecznego silnika gier. Zachowaj pełne polskie diakrytyki (ą,ć,ę,ł,ń,ó,ś,ź,ż). Zwróć JSON {\"text\": \"...\", \"glyphs_ok\": true}."},
    {"role": "user", "content": "<source string + context>"}
  ]
}
```
Reject any response with `glyphs_ok=false` or missing diacritics regex `[ąćęłńóśźż]` where source clearly demands them.

---

## Phase 1 — Backlog Status Discipline + Memory Refresh
*(item 7, plus stale memory entry)*

### Changes

#### File: `.ai/tasks/backlog.yaml`
- **What**: Flip statuses for tasks whose adapters are not in `_build_default_ports()`.
- **Where**: TASK-025 (progression), TASK-029 (parent zone — needs verification), TASK-036 (security/encrypted vault), TASK-042 (voice moderation), TASK-048 (COPPA lifecycle).
- **Rationale**: Backlog is the contract with the multi-agent team; lying statuses cause downstream tasks (TASK-049 threat model) to start on false premises.
- **Code sketch**:
  ```yaml
  - id: TASK-036
    status: in_review   # was: done; unwired in main.gd:138-217
    blocking_reason: EncryptedParentalPolicyStore not in _build_default_ports
  ```

#### File: `/Users/jakubsikora/.claude/projects/-Users-jakubsikora-Repos-choyce-engine/memory/MEMORY.md`
- **What**: Remove stale F-055-01 entry (KEY_REQUEST_AI_HELP_PORT now wired at `main.gd:200`); add note that F-055/F-060 family needs re-triage post-Phase 2.

#### New file: `.github/workflows/composition-root-gate.yml` (optional but recommended)
- **What**: CI gate failing any PR that adds `status: done` to backlog.yaml without touching `src/adapters/inbound/main.gd`.

### Success Criteria
#### Automated
- [ ] `grep -c "status: done" .ai/tasks/backlog.yaml` matches verified-wired count.
- [ ] CI gate passes on a synthetic test PR.
#### Manual
- [ ] Each `done` task traces to a line in `_build_default_ports()` or to a non-runtime artifact.

### Dependencies
- Requires: nothing.
- Blocks: nothing (parallel with later phases).

---

## Phase 2 — Release Blocker A: COPPA Data Lifecycle Wiring
*(items 1, 9)*

### Changes

#### File: `src/adapters/inbound/main.gd`
- **What**: Construct `ManageDataLifecycleService`, expose under new key `KEY_DATA_LIFECYCLE_PORT`. Replace `LocalConsentStore.new().setup()` with `FilesystemConsentStore.new().setup("user://choyce_consent")`.
- **Where**: `_build_default_ports()` lines 138-217.
- **Code sketch**:
  ```gdscript
  var data_lifecycle := ManageDataLifecycleService.new().setup(
      project_store, publish_store, consent_store, audit_ledger, event_bus, clock
  )
  # ...
  KEY_DATA_LIFECYCLE_PORT: data_lifecycle,
  ```

#### New file: `src/adapters/outbound/filesystem_consent_store.gd`
- JSON at `user://choyce_consent/consents.json`, fsync on write.

#### File: `src/adapters/inbound/scenes/parent/parent_zone_shell.gd`
- **What**: Add `manage_data_lifecycle_port` parameter to `setup()`; wire to new "Dane mojego dziecka" tab.
- **Where**: `setup()` (~line 60), `_apply_role_guard()` (lines 80-94).

#### File: `src/adapters/inbound/scenes/parent/parent_zone_shell.tscn`
- Panel with "Eksportuj dane" + "Usuń dane" buttons + confirmation dialog.

#### File: `src/adapters/inbound/scenes/parent/parent_zone_shell.gd` (fix)
- **What**: Guard `_apply_role_guard()` to no-op when `_profile == null`; only run after profile bound in `setup()`.
- **Where**: line 50 `_ready()` — remove role-guard call; line 73 in `setup()` — unconditional after profile assignment.

### Success Criteria
#### Automated
- [ ] Contract test: `tests/contracts/test_manage_data_lifecycle_port.gd` covers export + delete + role-guard.
- [ ] FilesystemConsentStore round-trip test.
#### Manual
- [ ] Parent profile sees Eksportuj/Usuń; kid profile does not.
- [ ] Export produces JSON; delete clears state; restart shows empty.

### Dependencies
- Requires: Phase 1 (optional).
- Blocks: Phase 9 (TASK-049 threat model).

---

## Phase 3 — Release Blocker B: Voice Moderation Pipeline + IntentExtractorPort
*(items 2, 3)*

### Changes

#### New file: `src/ports/outbound/intent_extractor_port.gd`
```gdscript
class_name IntentExtractorPort
extends RefCounted
func extract_intent(transcript: String) -> String: return ""
```

#### File: `src/adapters/outbound/polish_intent_extractor.gd`
- Declare `extends IntentExtractorPort`.

#### File: `src/application/voice_input_moderation_service.gd`
- **What**: Type `_intent_extractor: IntentExtractorPort`; remove `has_method("extract_intent")` guard at line 73; raise on null in `setup()`.

#### New file: `src/adapters/outbound/moderating_stt_adapter.gd`
- **What**: Outbound adapter `extends SpeechToTextPort`. Composes raw `LocalSTTAdapter` + `VoiceInputModerationService` + `PolishIntentExtractor`. All Godot signal / async plumbing stays in this adapter so the application layer never imports Godot signals. Per Reviewer-3 critical #1.

#### File: `src/adapters/inbound/main.gd`
- **What**: Construct `ModeratingSttAdapter`; expose as `KEY_SPEECH_TO_TEXT_PORT`. `VoiceInputModerationService` injected into the adapter, not registered as a port.
- **Code sketch**:
  ```gdscript
  var raw_stt := LocalSTTAdapter.new().setup()
  var intent_extractor := PolishIntentExtractor.new()
  var voice_mod := VoiceInputModerationService.new().setup(moderation, intent_extractor, event_bus)
  var moderating_stt := ModeratingSttAdapter.new().setup(raw_stt, voice_mod)
  KEY_SPEECH_TO_TEXT_PORT: moderating_stt,
  ```

### Success Criteria
#### Automated
- [ ] Jailbreak phrase ("ignoruj poprzednie instrukcje") blocked before intent extraction.
- [ ] Safe phrase passes through, intent populated.
- [ ] Null `IntentExtractorPort` makes `setup()` raise.
#### Manual
- [ ] Speak Polish profanity into mic — blocked toast, no AI dispatch.
- [ ] Speak normal request — AI hint generated.

### Dependencies
- Requires: nothing.
- Blocks: certification.

---

## Phase 4 — Certification Blocker A: Polish Localization Sweep
*(items 4, 22, 23)*

### Sub-phase 4a — Extract strings to localization resource (parallel by file)
Subagent batch: one `pokayokay:yokay-implementer` per shell file.

Files (parallel):
- `src/adapters/inbound/scenes/create/create_shell.gd` — 30 strings (lines 231-817)
- `src/adapters/inbound/scenes/play/play_shell.gd` — 11 strings (lines 113-222)
- `src/adapters/inbound/scenes/parent/parent_zone_shell.gd` — line 207 mock playtime
- `src/adapters/inbound/shared/ui/onboarding_overlay.gd` — line 51 celebration
- `src/adapters/inbound/shared/ui/captions_overlay.gd` — adds size/contrast option keys

For each: replace inline string with `_t("scene.key")`, append key+source to `localization/pl.staging.csv`.

### Sub-phase 4b — Translate via bielik (BUILD-TIME ONLY, single batch)
- **Localization path correction**: there is no `pl.csv`. Strings live in `src/adapters/outbound/polish_localization_policy.gd` (implements `LocalizationPolicyPort`). Shells call `_t(key)` which delegates to the port. Bielik output is merged into the adapter's key→value table.
- **Build-time only**: bielik is invoked from a `scripts/translate-strings.py` (or `.gd` cli) tool at authoring time. The running game NEVER calls `http://litellm`. CI gate verifies every `_t("…")` call site has a key in the adapter before any release tag.
- POST staging keys to `http://litellm` in chunks of ≤50; verify diacritic regex; merge into `PolishLocalizationPolicy`.
- Every translated row must satisfy `glyphs_ok:true` AND match `[ąćęłńóśźż]` where the English source implies it.
- **Kid register**: extend system prompt with: `"Pisz prostym językiem dla dzieci 5-10 lat: krótkie zdania (max 6 słów), drugą osobę liczby pojedynczej, czasowniki w trybie rozkazującym, unikaj rzeczowników abstrakcyjnych."`
- **Sampling rule**: ≥80% of kid-visible keys (anything reachable from create/play/onboarding/captions) sampled for human review. Adult parent-only strings sampled at ≥20%.

### Sub-phase 4c — Onboarding overlay UX fixes (item 22)
- File: `src/adapters/inbound/shared/ui/onboarding_overlay.gd`
- Add 30s auto-dismiss + visible "Pomiń" button; remove unconditional `MOUSE_FILTER_STOP`.

### Sub-phase 4d — Captions accessibility (item 23)
- File: `src/adapters/inbound/shared/ui/captions_overlay.gd`
- Add `font_size` setting (24/32/40 px), high-contrast toggle, position bottom/top.

### Success Criteria
#### Automated
- [ ] `rg '"[A-ZŚĆŻŹĘĄŁŃÓ][^"]*"' src/adapters/inbound/scenes/ src/adapters/inbound/shared/ui/` returns zero hits for Polish-looking literals outside `_t()` arg position. (Reviewer-1 corrected the inverted regex from v1 — we want to *find* hardcoded Polish in shells and *fail* the build, not require diacritics in code.)
- [ ] Every `_t("…")` call has a matching key in `PolishLocalizationPolicy._table` (CI script greps call sites + introspects adapter dict).
- [ ] Diacritic linter passes on `PolishLocalizationPolicy._table` values (regex `[ąćęłńóśźż]` must match where the English source implies — whitelist for proper nouns).
#### Manual
- [ ] Visual scan of create / play / parent / library shells — Polish reads native.
- [ ] Onboarding overlay skippable within 30s.
- [ ] Captions legible at 40px high-contrast.

### Dependencies
- Requires: nothing.
- Blocks: certification sign-off.

---

## Phase 5 — Certification Blocker B: Polish Prompt-Injection Patterns + Term-List Merge
*(items 5, 6)*

### Changes

#### File: `src/adapters/outbound/prompt_injection_filter.gd`
- Add Polish patterns: `"ignoruj poprzednie instrukcje"`, `"zignoruj wszystkie"`, `"teraz jesteś"`, `"nowe instrukcje:"`, `"od teraz"`, `"zapomnij"`, `"udawaj że"`, plus diacritic-stripped variants.
- Bielik can extend the list — invoke once with: "Podaj 20 polskich fraz prompt-injection w stylu jailbreak", review, add.

#### File: `src/adapters/outbound/local_moderation_adapter.gd`
- Add `photoreal_human` category with terms from `visual_asset_generation_service.gd:13-22`.

#### File: `src/application/visual_asset_generation_service.gd`
- Delete local `PHOTOREAL_HUMAN_TERMS` constant; rely solely on `moderation.check_text()`.

### Success Criteria
#### Automated
- [ ] Filter unit tests cover 10 Polish + 10 English jailbreak phrases.
- [ ] Single moderation call rejects "fotorealistyczny portret dziecka".
#### Manual
- [ ] Penetration test: the 7 added Polish phrases through both kid voice and creation prompt.

### Dependencies
- Requires: nothing. (Reviewer-1 flagged false 5→3 edge; injection filter is independent.)

---

## Phase 6 — Composition-Root Hardening: Encrypted Vault + Persistent Stores
*(items 8, 10)*

### Changes

#### File: `src/adapters/inbound/main.gd`
- Replace in-memory adapters with persistent variants. Greenfield — no migration.
  ```gdscript
  var policy_store := EncryptedParentalPolicyStore.new().setup(
      LocalEncryptedStorage.new().setup(signing_key)
  )
  var publish_store := FilesystemPublishStore.new().setup("user://choyce_publish")
  ```

#### New file: `src/adapters/outbound/filesystem_publish_store.gd`
- Mirror `FilesystemProjectStore` pattern. JSON per published world.

#### Key bootstrap
- `signing_key` sourced from `OS.get_environment("CHOYCE_VAULT_KEY")`. If missing in dev, generate per-install in `user://choyce_vault/key` (restrictive permissions). Hard fail in prod when env var missing.

#### Decryption failure path (safety default — per Reviewer-3 warning)
- On HMAC/AES decryption failure (key mismatch, corruption): `EncryptedParentalPolicyStore.load()` MUST return the deny-all / most-restrictive policy AND emit `ParentalPolicyDecryptionFailedEvent` to the audit ledger. Never throw, never return null. This honors the CLAUDE.md `consent → deny` failsafe.

### Success Criteria
#### Automated
- [ ] `tests/adapters/test_encrypted_parental_policy_store.gd` round-trip two instances.
- [ ] `tests/adapters/test_filesystem_publish_store.gd` survives simulated restart.
#### Manual
- [ ] Set a parental control; restart; control persists.
- [ ] Publish a world; restart; world still in library.

### Dependencies
- Requires: nothing. (Reviewer-1 flagged false 6→2 edge; encrypted vault swap has no functional dep on COPPA wiring.)

---

## Phase 7 — Architectural Debt
*(items 16, 17, 18, 19, 20, 21)*

Run as one batched swarm — six independent subagents in parallel.

### 7a — Bound `_pending_actions` / `_actions` maps
- Files: `src/application/approve_ai_patch_service.gd:10,26`, `src/application/ai_patch_workflow_service.gd:11,30`
- Pattern: copy `MAX_CACHE_ENTRIES = 1000` + `_cache_order: Array[String]` from `deterministic_tool_execution_gateway.gd:148`.

### 7b — `EnvironmentPort` extraction
- New: `src/ports/outbound/environment_port.gd` with `get_env(key: String) -> String`.
- New: `src/adapters/outbound/os_environment_adapter.gd` — production wrapper around `OS.get_environment()`.
- Edit: `src/application/feature_flag_service.gd:22`, `src/application/deployment_config.gd:25` — inject port.
- Edit: `main.gd:_build_default_ports` — construct + inject.

### 7c — Remove `signal` from domain/application
- Files: `src/domain/gameplay/quest_log.gd:7-10`, `src/application/onboarding_service.gd:7-9`
- Replace with `DomainEventBus.emit(...)`.
- **Pre-condition (hard gate, per Reviewer-3 critical #4)**: subagent must produce a complete `.connect()` call-site list via `rg -n "quest_log.*\.connect\(|onboarding_service.*\.connect\("` BEFORE editing. List enumerated in PR description. Each subscriber gets a corresponding `event_bus.subscribe(EventType, callable)` change. No silent runtime failure tolerated.

### 7d — Replace non-crypto `.hash()` with `String.sha256_text()`
- Helper:
  ```gdscript
  static func make_id(prefix: String, payload: String) -> String:
      return "%s-%s" % [prefix, payload.sha256_text().substr(0, 16)]
  ```
- 11 call sites: `parent_script_editor_service.gd:195`, `ai_failsafe_controller.gd:41`, `audio_governance_service.gd:321,374`, `visual_asset_generation_service.gd:134,313,345,405`, `voice_input_moderation_service.gd:118`, `ai_memory_layer_service.gd:198`, `deterministic_tool_execution_gateway.gd:148`, `ollama_llm_adapter.gd:414`.

### 7e — Remove redundant `has_method` guards
- Files: `request_ai_creation_help_service.gd:536,541`, `offline_autosave_service.gd:91,140`.
- Replace with null check or rely on port contract.

### 7f — Audit double-source disambiguation
- File: `src/adapters/inbound/main.gd:152-158`
- Decide: event_bus subscription is source of truth; remove direct ledger writes from `parent_audit_read_model_adapter` callers (or vice versa). Document chosen path in `docs/security/audit-flow.md`.

### Success Criteria
#### Automated
- [ ] No `signal` in `src/domain/` or `src/application/`.
- [ ] No `OS.get_environment` outside `src/adapters/`.
- [ ] No `.hash()` for ID construction in `src/application/`.
- [ ] Every map field has either a `MAX_*` constant or an eviction path.
#### Manual
- [ ] Long-running session (1h scripted) — memory does not grow unbounded.

### Dependencies
- Requires: nothing.

---

## Phase 8 — Performance
*(items 11, 12, 13, 14, 15, 24)*

### 8a — Async + streaming Ollama (rip-and-replace, no feature flag — user decision)
- File: `src/adapters/outbound/ollama_llm_adapter.gd:172, 220, 323-385`
- Replace synchronous `HTTPClient`+`delay_msec` with `HTTPRequest` Node; enable `"stream": true`. The `HTTPRequest` Node lives entirely inside the outbound adapter.
- **Hex contract (per Reviewer-3 critical #2)**: `LLMPort.complete()` accepts `on_token: Callable` and `on_done: Callable` arguments. The adapter receives the Godot `request_completed` signal and invokes the Callable — application services never import or await a Godot signal.
- Application caller pattern:
  ```gdscript
  llm.complete(prompt, options, _on_token, _on_done)
  ```
- Token coalescing: adapter accumulates tokens in a ring buffer; flushes via `_process` at fixed 30 Hz (max one Callable invocation per frame). Drop policy: if buffer > 4 KB unread, oldest tokens dropped + warning logged. Prevents unbounded signal queue (per Reviewer-5 warning #4).
- `cancel()` method on port; adapter aborts `HTTPRequest` and drains ring buffer.

### 8b — Moderation tokenizer rewrite
- File: `src/adapters/outbound/local_moderation_adapter.gd:90-105, 164-186`
- Use `PackedStringArray` accumulator; single-pass tokenize via `String.split()` + `String.to_lower()`; flatten categories to `{term: category_id}` dict at `setup()` for O(1) lookup.

### 8c — Audit ledger bounding (preserves hash chain — per Reviewer-3 critical #3)
- Files: `src/adapters/outbound/in_memory_audit_ledger.gd`, `filesystem_audit_ledger.gd`
- Rolling window cap `MAX_RECORDS = 50_000` with **segment-sealed archive rotation**.
- **Segment seal protocol**: when rotation fires, the adapter writes `segment_N.jsonl` (append-only JSON-lines) + `segment_N.seal` containing `{prev_seal_hash, segment_root_hash, last_record_hash, segment_id, signed_at}` signed with the same vault key as Phase 6. The active window's first record's `prev_hash` field references the latest seal's `last_record_hash`. Chain is unbroken across rotations.
- `verify_integrity(scope: full | active)` walks seals from origin when `full`; when `active`, verifies the active window references the most recent seal and seal signature is valid.
- Index by `actor_id` and `event_type` for active window only; archived segments are scan-only.
- **Rotation I/O on background thread (per Reviewer-5 warning #3)**: rotation flush dispatched to `WorkerThreadPool.add_task`; `append()` never blocks on archive write. Active-window swap is atomic via in-memory pointer flip.

### 8d — Defer non-critical adapters at startup (with input gate — per Reviewer-5 critical #2)
- File: `src/adapters/inbound/main.gd` `_ready` then `_build_default_ports`
- Move audit ledger init, moderation rules JSON parse, model catalog parse into `call_deferred("_build_default_ports_phase_2")`.
- **Input gate**: inbound shells observe `ports_ready` signal; until fired, voice input button, AI help button, and any prompt-emitting control are `disabled = true` with a Polish loading hint. Default fallback policy = BLOCK if any check fires during the gate. No unmoderated input reaches LLM in the first-frame window.

### 8e — Real performance tests
- File: `tests/performance/run_performance_benchmarks.gd:141-215`
- Replace `Node3D.new()` benchmarks with:
  - Ollama mock round-trip (P95 < 200ms)
  - Moderation on 1000-message corpus (< 50ms total)
  - Audit append 10_000 records (< 1s)
  - Cold start full `_build_default_ports` (< 250ms first frame)
- Budgets documented in `docs/release/performance-budgets.md`.

### 8f — Replace fabricated session-end stats (item 24)
- File: `src/adapters/inbound/scenes/play/play_shell.gd:175-184`
- Read real session progression from `KEY_KID_STATUS_READ_MODEL`; drop `randi() % 5` and `"~2 min"`.

### Success Criteria
#### Automated
- [ ] Perf tests pass within budgets.
- [ ] `grep "OS.delay_msec" src/adapters/outbound/ollama_llm_adapter.gd` empty.
- [ ] Cold-start trace shows `_ready` returns < 50ms.
#### Manual
- [ ] Tap "AI help" — token streaming within 500ms or spinner with `Anuluj`.
- [ ] Session end shows real collectible count + actual elapsed time.

### Dependencies
- Requires: nothing. (Reviewer-1 flagged false 8→7d edge; sha256 helper is independent of perf work.)

---

## Phase 9 — RBAC + UX Hardening

### Changes

#### File: `src/adapters/inbound/scenes/library/library_shell.gd:123, 193-197`
- Inside `_on_approve_pressed`, `_on_reject_pressed`, `_on_unpublish_pressed`: assert `_profile.is_parent()` before invoking port.

#### File: `src/adapters/inbound/scenes/play/play_shell.gd:120-131`
- When no active world, show actionable CTA "Stwórz świat" button.

#### File: `src/adapters/inbound/scenes/create/create_shell.gd:304-306`
- When `_apply_world_edit_port == null`, disable tool buttons in addition to toast.

### Success Criteria
#### Automated
- [ ] Unit test: kid profile cannot call `review_publish_port.approve()` through library handlers.
#### Manual
- [ ] Kid profile sees disabled approve/reject AND debug-invocation rejected at handler level.
- [ ] "Graj Solo" with no world shows clear CTA.

### Dependencies
- Requires: nothing. (Reviewer-1 flagged false 9→2 edge; library RBAC handlers independent of COPPA wiring.)

---

## Phase 10 — Final Verification + Backlog Reconciliation

### Steps
1. Run full quality gates: `scripts/run-quality-gates.sh` + `scripts/ci/run-safety-gates.sh` + `scripts/ci/run-inbound-shell-regression.sh` + AI vision tests (`scripts/ci/run-ai-vision-tests.sh`).
2. Manual QA pass over `.ai/manual-qa/` checklists — close F-055-01/02/03, F-056-01, F-059-01, F-060-01/02.
3. Re-run `pokayokay:yokay-auditor` on requirements docs — every requirement at L4 or L5.
4. Flip backlog statuses back to `done`; reconcile memory.
5. Dispatch `pokayokay:yokay-spec-reviewer` for adversarial final check.

### Success Criteria
- [ ] All automated criteria from Phases 2-9 green simultaneously.
- [ ] Manual QA blockers closed.
- [ ] Auditor report: zero L1/L2/L3 features remaining for documented requirements.

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Bielik translation drift (off-tone for kids) | Med | Med | Sample 20 keys for human review; pin system prompt; cache `glyphs_ok` rejections |
| Async Ollama breaks existing AI flows (await contract) | Med | High | Phase 8a behind feature flag; keep sync adapter one release for rollback |
| Greenfield wipe of dev-test data | High | Low | Communicate; dev fixture seeder script if needed |
| Composition root grows monolithic | Med | Med | Split `_build_default_ports` into per-context builder functions in Phase 8d |
| Encryption key loss in dev | Med | Med | Auto-regenerate in dev, hard fail in prod with explicit env var |
| Performance budgets too tight on slow CI | Low | Med | Budgets parameterized by `CI_PERF_MULTIPLIER` env var |
| Polish injection list incomplete | High | High | Bielik-generated list + threat model review in TASK-049 |

## Rollback Strategy
- Each phase ships as a separate PR. Branch-per-phase so individual revert is trivial.
- Phase 8a (async Ollama) gated behind `feature_flag_service.is_enabled("ollama_async")`.
- Persistent stores (Phase 6) ship with `CHOYCE_PERSISTENCE_MODE=in_memory` env override for emergency fallback.
- Backlog statuses are git-tracked; revert by `git revert`.

## File Ownership Summary

| File | Phase | Change Type |
|------|-------|-------------|
| `.ai/tasks/backlog.yaml` | 1, 10 | Modify |
| `~/.claude/.../memory/MEMORY.md` | 1, 10 | Modify |
| `src/adapters/inbound/main.gd` | 2, 3, 6, 7b, 8d | Modify |
| `src/adapters/inbound/scenes/parent/parent_zone_shell.{gd,tscn}` | 2 | Modify |
| `src/adapters/outbound/filesystem_consent_store.gd` | 2 | Create |
| `src/ports/outbound/intent_extractor_port.gd` | 3 | Create |
| `src/adapters/outbound/polish_intent_extractor.gd` | 3 | Modify |
| `src/application/voice_input_moderation_service.gd` | 3 | Modify |
| `src/adapters/inbound/scenes/{create,play,library}/*` | 4, 9 | Modify |
| `src/adapters/inbound/shared/ui/{onboarding,captions}_overlay.gd` | 4 | Modify |
| `localization/pl.csv` | 4 | Modify/Create |
| `src/adapters/outbound/prompt_injection_filter.gd` | 5 | Modify |
| `src/adapters/outbound/local_moderation_adapter.gd` | 5, 8b | Modify |
| `src/application/visual_asset_generation_service.gd` | 5, 7d | Modify |
| `src/adapters/outbound/filesystem_publish_store.gd` | 6 | Create |
| `src/application/{approve_ai_patch,ai_patch_workflow}_service.gd` | 7a | Modify |
| `src/ports/outbound/environment_port.gd` | 7b | Create |
| `src/adapters/outbound/os_environment_adapter.gd` | 7b | Create |
| `src/application/{feature_flag,deployment_config}.gd` | 7b | Modify |
| `src/domain/gameplay/quest_log.gd` | 7c | Modify |
| `src/application/onboarding_service.gd` | 7c | Modify |
| 11 application services (sha256 IDs) | 7d | Modify |
| `src/application/{request_ai_creation_help,offline_autosave}_service.gd` | 7e | Modify |
| `docs/security/audit-flow.md` | 7f | Create |
| `src/adapters/outbound/ollama_llm_adapter.gd` | 8a | Modify |
| `src/adapters/outbound/{in_memory,filesystem}_audit_ledger.gd` | 8c | Modify |
| `tests/performance/run_performance_benchmarks.gd` | 8e | Modify |
| `docs/release/performance-budgets.md` | 8e | Create |
| `.github/workflows/composition-root-gate.yml` | 1 | Create (optional) |

## Uncertainties to Flag

1. **TASK-029 wiring status** — research shows progression/clone/remix services unwired, but TASK-029 specifically covered parent zone parental policy (which IS wired). Need a 5-minute audit at start of Phase 2 to confirm exactly which TASK-029 deliverables are live.
2. **`signal` removal in `QuestLog`** — may have UI subscribers expecting Godot signal semantics. Grep callers before swapping to `DomainEventBus`.
3. **Bielik availability** — assumed reachable at `http://litellm`. If proxy uses different host or auth, adjust Phase 4b invocation.
4. **Audit ledger archival format** — Phase 8c proposes rotation; decide JSON-lines vs binary for archived chunks (impacts replay tooling).
5. **Performance budgets on lowest-end target device** — unknown until named. Plan assumes a mid-2018 entry-level Windows laptop / 2020 iPad as baseline.

---

# Revision 2 — Folded User Decisions + 5-Reviewer Feedback (2026-05-18)

## User decisions (locked in)
1. Phase order — keep as drafted.
2. Encryption key handling — keep design; **plus deny-all fallback on decryption failure** (folded into Phase 6).
3. Async Ollama — **rip-and-replace** (no feature flag). Phase 8a updated; risk table entry retired.
4. Localization path verified — strings live in `PolishLocalizationPolicy` adapter, not `pl.csv`. Phase 4b corrected.
5. Bielik endpoint — `http://litellm` confirmed; **declared BUILD-TIME ONLY**, runtime game never calls litellm.

## Inline patches applied (above)
- **Phase 3**: introduced `ModeratingSttAdapter` in `src/adapters/outbound/`; `VoiceInputModerationService` is composed inside the adapter, no longer registered as a port. Closes Reviewer-3 critical #1 (hex violation).
- **Phase 4b**: declared BUILD-TIME ONLY; corrected localization target to `PolishLocalizationPolicy`; added kid-register clause to bielik system prompt; sampling rule = ≥80% of kid-visible keys.
- **Phase 4 success criteria**: regex corrected to detect hardcoded Polish in shells (Reviewer-1 catch).
- **Phase 6**: added decryption-failure path returning deny-all policy + audit event (Reviewer-3 warning).
- **Phase 7c**: mandatory `rg` grep audit of `.connect()` sites as a hard pre-condition (Reviewer-3 critical #4).
- **Phase 8a**: ripped feature flag; `LLMPort.complete()` takes `on_token`/`on_done` Callables; adapter translates Godot signal; ring-buffer coalescing at 30 Hz with drop policy (Reviewer-3 critical #2 + Reviewer-5 warning #4).
- **Phase 8c**: segment-sealed archive rotation preserves hash chain; rotation I/O on `WorkerThreadPool` (Reviewer-3 critical #3 + Reviewer-5 warning #3).
- **Phase 8d**: `ports_ready` input gate prevents first-frame unmoderated input (Reviewer-5 critical #2).
- **Spurious deps dropped**: 5→3, 6→2, 8→7d, 9→2 (Reviewer-1).

## Additional changes — to apply during Phase execution

### Phase 1 sequencing fix (Reviewer-1)
- Backlog status flip happens in **Phase 10**, not Phase 1. Phase 1 is reduced to: memory refresh + CI gate workflow only. Avoids "in_review → done" churn.

### Phase 2 — TSCN node-path explicit (Reviewer-2 FR-023 gap)
- The `manage_data_lifecycle_port` tab must be added at node path `parent_zone_shell/TabContainer/DaneTab`. Plan author commits to a `.tscn` diff in PR, not just GDScript wiring.

### Phase 4c — onboarding overlay for non-readers (Reviewer-4)
- 30 s auto-dismiss is **not** sufficient. Add: ear icon next to "Pomiń" + TTS prompt at 5 s ("Możesz pominąć"). Remove `MOUSE_FILTER_STOP` unconditionally; replace with `MOUSE_FILTER_PASS` so taps anywhere advance the overlay.

### Phase 4d — captions audio fallback (Reviewer-4)
- Add TTS narration toggle (uses existing audio-governance pipeline). Captions never the only modality.

### Phase 5 — bielik-generated injection list (Reviewer-1 + Reviewer-3 warning)
- 7 phrases is a hard floor, not a ceiling. Bielik invocation produces a **proposed extension**; every proposed phrase requires human OK before merge. No auto-merge of LLM-generated safety patterns.

### Phase 8e — pinned baseline device (Reviewer-5 critical #1)
- **Baseline pinned**: Lenovo Tab M8 4th gen (Helio A22, 3 GB, eMMC 5.1). CI runs perf suite with `CI_PERF_MULTIPLIER` calibrated against a manual baseline run on this device, logged to `docs/release/performance-baseline.md`. Phase 8e merge blocked until baseline run uploaded.
- Budgets re-stated as ratios (e.g. "cold start ≤ 1.0× baseline + 50 ms tolerance") rather than absolute ms.

### Phase 8f — kid-positive stat framing (Reviewer-4)
- Zero-value session-end stats suppressed; replaced with `"Świetna robota! Wróć po więcej."` fallback. No bare "0 znajdziek" screen.

### Phase 9 — non-reader CTA (Reviewer-4)
- "Stwórz świat" CTA gets accompanying icon (hammer + plus pictogram) and TTS prompt on focus. Voice prompt triggered after 3 s of no interaction.

### `_t()` cache + filesystem debounce (Reviewer-5 suggestion)
- `PolishLocalizationPolicy._table` loaded once at `setup()` into a `Dictionary` field; `_t()` is O(1) dict lookup, no re-parse per call.
- All filesystem stores (`FilesystemPublishStore`, `FilesystemConsentStore`, `FilesystemAuditLedger`) gain a 250 ms trailing debounce timer; rapid writes coalesce into one fsync.

### Phase 8b term-dict cap (Reviewer-5 suggestion)
- Add `MAX_MODERATION_TERMS = 5_000`. Adapter logs a warning + truncates if rules file exceeds the cap.

## Scope deferred to follow-up plan (Reviewer-2 FR gaps)

The following requirements are **outside this plan's scope** and need a follow-up plan after Phases 2/3/6 land. Logged here so they are not silently dropped:

| FR | Description | Owner suggestion |
|----|-------------|------------------|
| FR-013 / FR-AI-005/006/007 | AI gameplay companion in `play_shell` | new TASK — claude/codex |
| FR-016 | Progression/clone/remix services (TASK-025) wiring | codex |
| FR-019 | Marketplace/library navigation UI | copilot |
| FR-025 | Parent dashboard time-limits, friend controls, AI-policy UI | copilot |
| FR-031 | Template content (`data/templates/*.json`) localized via `_t()` pipeline | copilot |
| UX-AI-002 | Preview/Apply/Undo on every AI card | copilot |
| UX-KID-001 / UX-004 | Voice narration for menu labels and tooltips | copilot |

After Phase 10 closes, run yokay-auditor again; reopen TASK-025 if still L1, file new tasks for FR-013/019/025/031 + UX-AI-002.

## F-055-01 verification step (Reviewer-2)
Phase 1 also runs a one-shot grep: `rg "KEY_REQUEST_AI_HELP_PORT" src/adapters/inbound/main.gd` — confirm a non-zero count before deleting the memory entry. Avoid trusting memory blindly.

## Reversibility / schema versioning (Reviewer-3 suggestion)
Phases touching event or data schemas (7c signal→event, 7d sha256 IDs, 8a streaming contract, 8c segment seals) each ship with:
- a version bump field in the serialized envelope (`schema_version: int`)
- a one-PR shim in the prior phase release that accepts both old and new formats
- a documented "revert window" — minimum 1 release cycle of dual-format support before old format dropped

## Updated Risk Table additions

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Bielik produces grammatical but adult-register Polish | High | High | Kid-register clause in system prompt + ≥80% kid-visible sample human-reviewed |
| Async Ollama signal queue overflow | Med | Med | Ring buffer + drop policy + 30 Hz flush (Phase 8a) |
| Hash chain broken by archive rotation | Med | High | Segment seals + signed envelope (Phase 8c) |
| First-frame race lets unmoderated input through | Med | High | `ports_ready` input gate (Phase 8d) |
| Encryption key rotation silently bricks parental policies | Med | High | Deny-all fallback + decryption-failure audit event (Phase 6) |
| Bielik-generated safety patterns merged without review | High | High | Hard floor of 7 curated phrases + per-phrase human OK |
| Perf budgets pass CI but fail target device | High | Med | Pinned baseline SKU + `CI_PERF_MULTIPLIER` |


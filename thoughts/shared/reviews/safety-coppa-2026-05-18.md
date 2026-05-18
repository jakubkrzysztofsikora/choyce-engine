---
date: 2026-05-18
reviewer: safety-coppa
commit: 68d73a3
status: complete
---
# Review: Safety / COPPA / Accessibility

## Summary
The post-research-findings wave landed the structural plumbing (FilesystemConsentStore, FilesystemDataLifecycleAdapter, EncryptedParentalPolicyStore, ManageDataLifecycleService wired into KEY_DATA_LIFECYCLE_PORT, parent zone Dane tab), but several **release-blocking** safety gaps remain. The three sharpest issues: (1) COPPA delete does NOT remove consent from disk because the lifecycle adapter calls a non-existent `FilesystemConsentStore._save()` method, (2) the voice safety bypass check in `voice_assistant_overlay.gd` reads the wrong dict key (`"blocked"` vs actual `"allowed"`) and therefore never fires, and (3) `ManageDataLifecycleService._is_subject_managed_by_parent` returns `true` on an empty `managed_profiles` array — combined with `role_guard=null` and an env-var-driven `is_parent()`, this collapses authorization to a single env variable.

## Findings (severity-ranked)

### Critical (block release)

- **C1. Voice moderation side-channel check is dead code.** `voice_assistant_overlay.gd:111` does `last_result.get("blocked", false) == true`, but `ModeratingSttAdapter.last_result` only sets the key `"allowed"` (see `moderating_stt_adapter.gd:52,67`). `"blocked"` is never written, so the guard is structurally non-functional. Today it appears safe only because blocked transcripts return `""` and the empty-prompt branch at line 116 catches it — but the explicit moderation BLOCK toast (`voice.blocked_try_again`) is never shown, so the kid sees "no speech" instead of being told the content was blocked. Any future refactor that allows non-empty prompts through the empty check will silently bypass moderation.
  - **Fix**: change to `not last_result.get("allowed", true)` or add a `"blocked"` mirror key in `ModeratingSttAdapter`.
  - File: `src/adapters/inbound/shared/ui/voice_assistant_overlay.gd:111`

- **C2. COPPA delete leaves consent data on disk.** `FilesystemDataLifecycleAdapter._clear_profile_consent` (lines 160-174) reaches into the private `_consent_store._profiles` dict to erase the entry, then duck-types `_consent_store.has_method("_save")` — but `FilesystemConsentStore` has **no `_save` method** (only `_flush_to_disk`). `_dirty` is never flagged because the public API was bypassed. The next `flush_if_due` is a no-op (`_dirty == false`), and on shutdown the old file is rewritten as-is from in-memory state — but the next process boot reloads from disk into `_profiles`, and we just lost the in-memory erase. End result: consent for the deleted profile **persists on disk** across restarts. This is a textbook COPPA/GDPR-K violation.
  - **Fix**: add `FilesystemConsentStore.delete_profile(profile_id)` that erases + `_mark_dirty()` + `flush()`, replace duck-typed `_save` call with that.
  - File: `src/adapters/outbound/filesystem_data_lifecycle_adapter.gd:172-173`

- **C3. COPPA authorization defaults to allow.** `ManageDataLifecycleService._is_subject_managed_by_parent` returns `true` when `managed_profiles` is empty (line 170-171) and `true` when `managed_profiles` is not an Array at all (line 173). Combined with: (a) `_role_guard = null` is passed in `main.gd:363`, (b) `_profile.is_parent()` is the only remaining check and it is driven solely by the `CHOYCE_PROFILE_ROLE=parent` env var (`main.gd:169-170`), and (c) `managed_profiles` is **never populated anywhere** in the codebase — the effective authorization for `request_delete` / `request_export` is "did you set an env var". A KID profile cannot trigger the dialog (parent-only guard in `_apply_role_guard`), but the service layer alone is unsafe and external callers / tests / future REST adapters would bypass UI guards entirely.
  - **Fix**: make `managed_profiles` empty-array → DENY (not allow) and require explicit population at profile build time.
  - File: `src/application/manage_data_lifecycle_service.gd:166-173`

- **C4. Failed COPPA authorization is not audited.** `_is_authorized()` returns `false` before reaching `_log_audit`. Per COPPA `§312.10`, all access attempts to children's personal data must be logged regardless of outcome. Today an attacker (or accidental kid login) attempting delete/export leaves zero forensic trace.
  - **Fix**: emit `DATA_DELETION_DENIED` / `DATA_EXPORT_DENIED` audit record with `actor.profile_id`, `subject_id`, and a denial reason before returning.
  - File: `src/application/manage_data_lifecycle_service.gd:32-50, 58-72`

### High

- **H1. Parent zone "Undo" and "Restore safe save" buttons are dead UI.** `parent_zone_shell.gd:44-45` declares `_undo_button` and `_safe_restore_button`, `_wire_actions()` (lines 121-130) only connects `_go_create_button`, `_go_play_button`, and `_apply_policy_button`. There is no `.pressed.connect()` for undo or safe-restore. These are core safety affordances per `CLAUDE.md` ("Require reversible changes for AI tool calls") and they don't work.
  - File: `src/adapters/inbound/scenes/parent/parent_zone_shell.gd:121-130`

- **H2. ParentZoneShell does not gate on `ports_ready`.** `main.gd:763-770` wires `on_ports_ready` only for `_create_shell`. ParentZoneShell has no `on_ports_ready` method, so if the parent navigates into the zone before phase-2 finishes (~1 frame), the COPPA Export/Delete buttons fire with `_manage_data_lifecycle_port == null` and surface a generic `save_failed` toast — kid-zone voice/AI uses the `_ports_ready` gate, parent COPPA does not.
  - File: `src/adapters/inbound/scenes/parent/parent_zone_shell.gd:54-90`

- **H3. Delete confirmation lacks friction.** The COPPA delete confirmation is a plain `ConfirmationDialog` with default OK/Cancel buttons (`parent_zone_shell.gd:278-281`). For an irreversible operation that destroys a child's profile data, best practice (and most COPPA-K certification tracks) require either a typed confirmation ("type DELETE"), a re-authentication step, or a multi-step countdown. Today a single mis-click in the parent zone wipes the kid's data.
  - File: `src/adapters/inbound/scenes/parent/parent_zone_shell.gd:312-326`

- **H4. Accessibility settings are session-only.** `main.gd:920-935` builds the a11y dialog and wires `.toggled.connect` lambdas to `_accessibility_policy`, but there is no load-from-disk on startup and no save-on-toggle. Each app restart resets dyslexia font / motor scale / captions to off — a child who needs dyslexia font must enable it every launch through a buried nav button. This violates WCAG 3.3.7 (consistent identification) and effectively the feature is unusable for the kids who need it most.
  - File: `src/adapters/inbound/main.gd:900-935`

- **H5. `FilesystemDataLifecycleAdapter` violates hex boundaries.** `_clear_profile_consent` (line 169-173) reaches into `FilesystemConsentStore._profiles` (private field) directly and duck-types `_save()`. Already flagged as a Wave C carry-over in memory; this is the implementation evidence that the carry-over has security consequences (C2 above), not just architectural smell.
  - File: `src/adapters/outbound/filesystem_data_lifecycle_adapter.gd:169-173`

### Medium

- **M1. Vault key auto-generated in editor mode silently.** `_resolve_vault_signing_key` (main.gd:564-625) treats `OS.has_feature("editor")` as dev mode and silently auto-generates a 32-byte vault key in `user://choyce_vault/key`. Anyone running the project with `godot --path .` (including a malicious dev or untrusted plugin) reads the cleartext key from disk and decrypts the parental policy vault. There is no key rotation, no integrity check on the keyfile itself, no encryption-at-rest of the key.
  - File: `src/adapters/inbound/main.gd:548-625`

- **M2. `_is_subject_managed_by_parent` fail-open on non-Array preferences.** Line 173 returns `true` if `managed_profiles` is anything other than an Array (string, null, Dictionary). Should default-deny.
  - File: `src/application/manage_data_lifecycle_service.gd:166-173`

- **M3. Moderation result `warn_child` semantics are ambiguous.** `local_moderation_adapter.gd:134,154` reads "if severity == warn_child and NOT a child → WARN", reaching `BLOCK` for children. The naming + inverted logic combination is error-prone. Either rename `warn_child` to `block_child_warn_other` or invert the comparison.
  - File: `src/adapters/outbound/local_moderation_adapter.gd:134,154`

- **M4. Audit record `_log_audit` does not include moderation verdict on COPPA actions.** Only action name + actor + subject + detail. Missing the dictionary payload from `request_delete`/`request_export` (scope, error reasons on retry). Forensic readability gap.
  - File: `src/application/manage_data_lifecycle_service.gd:195-213`

- **M5. `ManageDataLifecycleService.revoke_consent` only handles `cloud_sync`.** Line 117-127 hardcodes a single key path; other consent keys (`ai_generation`, `voice_input`, `telemetry`) are silently no-op-passed to backend without any policy update. Parent revoking `voice_input` consent will not stop voice capture because `FilesystemConsentStore` is never updated.
  - File: `src/application/manage_data_lifecycle_service.gd:99-145`

- **M6. `VoiceInputModerationService` does not emit safety intervention on null moderation_result.** Line 55-72 enters the block branch if `moderation_result == null` but the safety intervention event uses `moderation_result.category` (line 69) which will crash because line 67 already pulled `category` from a null result. Actually the ternary in line 69 handles it (returns `""`), but the same null check pattern relies on Godot short-circuit semantics — fragile.
  - File: `src/application/voice_input_moderation_service.gd:55-72`

### Low / nits

- **L1. `_get_subject_profile_id` fallback constructs `family_local_kid_1`.** `parent_zone_shell.gd:336-338`. Convention-over-config; if a family ID differs or there are siblings, fallback hits a phantom subject. Not security-critical because authorization eventually rejects, but UX feels broken.
- **L2. The parent zone "Dane mojego dziecka" panel is created programmatically and appended to `$Layout` (line 275).** Layout order depends on .tscn structure; in some screen sizes the panel renders below the fold with no scroll affordance.
- **L3. `apply_baseline_contrast` sets `font_color` to pure white on near-black background.** Strong contrast but kid-aesthetic mismatch with the rest of the bright cyan/lime kid theme — likely never applied because `_root_node.theme` was assigned in `_apply_theme` (parent_zone_shell.gd:347-349). Theme conflict between adapter and shell.
- **L4. `_apply_motor_overrides` recursively traverses the entire tree on every toggle (line 151-174).** O(N) tree walk on each a11y change; not a problem at current size but will scale poorly.
- **L5. `parent_zone_shell.gd:80-81` duck-types provenance badge `.setup()` — typical pattern.** Could be a typed port.
- **L6. `FilesystemConsentStore` has no LRU/size cap.** Unbounded growth across kids/years. Same recurring finding flagged in memory.

## Manual test log

Code-level review only — running under a worktree, did not boot Godot.

- Verified parse-clean check is gated by GDScript --check-only resolution issues (script dependency ordering); not a hard parse failure.
- `git log --oneline -1`: `68d73a3 feat(audio): SFXPlayer in gameplay uses AudioBank-loaded streams`
- Read all 11 axis files + composition root (`main.gd`) + `voice_assistant_overlay.gd` + ParentalControlPolicy + PlayerProfile + AgeBand + RoleTokenGuard + LocalEncryptedStorage + GodotAccessibilityAdapter.
- Did not execute the Godot binary; verification was static analysis only. Recommendation: a follow-up reviewer with manual access drive parent-zone Export, Delete flow and verify the `voice.blocked_try_again` toast NEVER fires under the dead-code path (C1).

## Recommendations (prioritized)

1. **Fix C1** — change `last_result.get("blocked", false)` to `not last_result.get("allowed", true)` in `voice_assistant_overlay.gd:111`. 1-line fix; biggest exposure-vs-effort win.
2. **Fix C2** — add `FilesystemConsentStore.delete_profile(profile_id)` (public, marks dirty, returns bool), call it from `FilesystemDataLifecycleAdapter._clear_profile_consent`, remove `_profiles` and `_save` reach-in.
3. **Fix C3 + C4 together** — in `ManageDataLifecycleService`:
   - `_is_subject_managed_by_parent` returns `false` when `managed_profiles` is empty or non-Array.
   - Populate `managed_profiles` at profile build time in `main.gd:_build_default_profile`.
   - Add `_log_audit_denial(action, actor, subject, reason)` call inside `_is_authorized` before each `return false` branch.
4. **Fix H1** — wire `_undo_button.pressed.connect(_on_undo_pressed)` / `_safe_restore_button.pressed.connect(_on_safe_restore_pressed)` and implement the handlers (route to `_set_parental_controls_port` revert flow or a new `KEY_UNDO_PORT`). Or hide buttons until backend exists.
5. **Fix H4** — load a11y state from a persistent settings dict (or extend `FilesystemConsentStore` with a `preferences` block keyed by profile) on startup and re-apply via `_accessibility_policy.set_*` calls inside `_setup_a11y_ui`.
6. **Add to backlog**: 
   - typed confirmation friction for COPPA delete (H3),
   - hex boundary cleanup `FilesystemDataLifecycleAdapter` → `FilesystemConsentStore` (H5 / Wave C carry-over),
   - vault keyfile hardening (M1).

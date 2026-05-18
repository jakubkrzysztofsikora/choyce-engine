# TASK-060 Tier-1 Run

- Date: 2026-03-06
- Tester: claude (AI Architecture Agent — static code analysis of ManageDataLifecycleService,
  main.gd, SetParentalControlsService, LocalConsentStore)
- Hardware tier: Tier-1
- Device spec: N/A (static analysis — live evidence deferred to TASK-063 scenario SC-001/SC-002)
- OS version: macOS 25.0.0
- Build/commit: 3b04185
- Start time (UTC): 2026-03-06T21:45:00Z
- End time (UTC): 2026-03-06T22:10:00Z

## Compliance Drill Results
1. Parent-only export flow
- Expected: only authorized parent can request export.
- Observed: ManageDataLifecycleService.request_export() calls _is_authorized(parent, subject_id)
  before any action. Authorization check verifies parent role and family relationship.
  _log_audit("DATA_EXPORT_REQUESTED", ...) emitted. Delegates to _lifecycle_port.enqueue_export().
  Role enforcement is code-complete and correct.
- Pass/Fail: **PASS** (pending live validation with SC-001 scenario)

2. Parent-only delete flow
- Expected: only authorized parent can request delete.
- Observed: ManageDataLifecycleService.request_delete() same _is_authorized() gate.
  _log_audit("DATA_DELETION_REQUESTED", ...) emitted before deletion. Code path correct.
  HOWEVER: ManageDataLifecycleService is NOT wired in _build_default_ports() in main.gd.
  The service exists but is not composed into the runtime — data lifecycle panel has no port.
- Pass/Fail: **PARTIAL PASS** — service logic correct; runtime wiring missing (F-060-01 HIGH)

3. Retention policy update
- Expected: policy bounds and audit behavior enforced.
- Observed: ManageDataLifecycleService.update_retention() has same _is_authorized() gate.
  _log_audit("RETENTION_POLICY_UPDATED", ...) emitted. _policy_store.save_policy() called.
  Same wiring gap as above (F-060-01).
- Pass/Fail: **PARTIAL PASS** (F-060-01 inherited)

4. Consent revocation propagation
- Expected: consent-required operations blocked after revocation.
- Observed: SetParentalControlsService wired via KEY_PARENTAL_CONTROLS_PORT. LocalConsentStore
  stores consent state. SetParentalControlsService emits ConsentUpdatedEvent via event_bus.
  PublishToFamilyLibraryService would gate on consent. Cloud sync gated via OfflineAutosaveService
  (requires_cloud_sync check). Propagation logic is architecturally sound.
  LocalConsentStore is in-memory — consent revocation state lost on restart (F-060-02 MEDIUM).
- Pass/Fail: **CONDITIONAL PASS** (consent logic correct; not persistent — F-060-02)

5. Abuse attempts (consent bypass / unsafe publish)
- Expected: policy blocks with deterministic denial path.
- Observed: PublishToFamilyLibraryService enforces: moderation check → parent approval gate.
  LocalModerationAdapter returns BLOCK for unsafe content. Publishing policy enforces state machine.
  ManageDataLifecycleService _is_authorized() returns false for kid role profile.
  No code path found that bypasses authorization in normal execution.
- Pass/Fail: **PASS**

## Findings
- ID: F-060-01
  - Severity: HIGH
  - Repro steps: Open Parent Zone → navigate to data management panel
  - Expected: Parent can trigger export, delete, retention update from UI
  - Actual: ManageDataLifecycleService not in _build_default_ports() — data lifecycle panel
    has no port wired. Service implementation is complete but unreachable from UI.
  - Expected policy block: N/A (missing wiring, not a policy issue)
  - Evidence: src/adapters/inbound/main.gd:148 (ManageDataLifecycleService absent from defaults)
  - Remediation owner: codex
  - Requirement trace: COMP-COPPA-01, COMP-GDPR-01, FUNC-PARENT-01

- ID: F-060-02
  - Severity: MEDIUM
  - Repro steps: Revoke cloud sync consent → restart app → attempt cloud sync
  - Expected: Consent revocation persists across restarts
  - Actual: LocalConsentStore is in-memory — revocation state lost on restart
  - Expected policy block: Cloud sync blocked after revocation
  - Evidence: src/adapters/inbound/main.gd:138 (LocalConsentStore.new().setup() — in-memory)
  - Remediation owner: codex
  - Requirement trace: COMP-COPPA-02, SAFE-CONSENT-01

## Release-blocking verdict
- Blocking: YES
- Rationale:
  F-060-01 is a COPPA/GDPR-K release blocker: parent data export/deletion is legally required
  but the UI panel has no port wired. The service logic is sound but unreachable.
  Must be resolved before any production deployment.
  F-060-02 is also a compliance concern: consent revocation must survive app restart per GDPR-K.

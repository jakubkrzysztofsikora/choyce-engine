# TASK-035 Handoff: Offline Autosave + Consent-Gated Cloud Sync

## Implementer: codex
## Cross-reviewer: claude

## Summary
Implemented offline-first autosave orchestration with a non-blocking queue, 30-second interval scheduling, and optional cloud sync gated by explicit consent.

## Files Created
- `src/ports/outbound/cloud_project_sync_port.gd`
- `src/adapters/outbound/in_memory_cloud_project_sync.gd`
- `src/application/offline_autosave_service.gd`
- `tests/contracts/cloud_project_sync_port_contract_test.gd`
- `tests/contracts/in_memory_cloud_project_sync_adapter_contract_test.gd`
- `tests/contracts/offline_autosave_service_contract_test.gd`
- `tests/adapters/inbound/test_parent_zone_controls_integration.gd` (TASK-029 completion dependency support)

## Files Updated
- `tests/contracts/run_contract_tests.gd` (added 3 contract registrations)
- `tests/contracts/README.md` (contract inventory updated)
- `src/domain/CONTEXT_MAP.md` (added `InMemoryCloudProjectSync` adapter entry)
- `src/adapters/inbound/scenes/parent/parent_zone_shell.gd` (TASK-029 dashboard control wiring)
- `src/adapters/inbound/scenes/parent/parent_zone_shell.tscn` (TASK-029 dashboard controls)
- `data/localization/ui_pl.json` (TASK-029 parent controls localization keys)

## Implementation Details
### OfflineAutosaveService
- Schedules autosave snapshots per project at configurable interval (`DEFAULT_AUTOSAVE_INTERVAL_MSEC = 30000`).
- Keeps I/O off active interaction path:
  - `maybe_schedule(...)` only enqueues cloned snapshots.
  - `process_pending(...)` performs local save when `interaction_active == false`.
- Uses bounded queue (`MAX_PENDING_SNAPSHOTS = 8`) to prevent unbounded memory growth.
- Performs optional cloud sync only when:
  - cloud adapter exists and `is_available()` returns true, and
  - explicit consent exists (`cloud_sync` or `parental_control_cloud_sync_consent`) on candidate profiles.

### Cloud Sync Port + Adapter
- `CloudProjectSyncPort` defines `sync_project(project)` and `is_available()`.
- `InMemoryCloudProjectSync` provides deterministic non-network adapter for contracts.

## Validation
Executed:
- `./scripts/run-contract-tests.sh`

Result:
- `Contracts: 54`
- `Checks: 696`
- `Failed contracts: 0`

Notable new passing contracts:
- `CloudProjectSyncPort` (4 checks)
- `InMemoryCloudProjectSyncAdapter` (10 checks)
- `OfflineAutosaveService` (14 checks)

## Acceptance Criteria Mapping
1. Autosave runs every 30 seconds without blocking active interaction:
- Enforced by interval gate in `maybe_schedule` and deferred I/O in `process_pending`.
- Active interaction bypasses persistence until interaction flag is cleared.

2. Cloud sync optional and requires explicit parent consent:
- Cloud sync is optional dependency (`cloud_sync = null` supported).
- Consent is required via IdentityConsentPort checks before sync execution.

## Review Focus Areas
1. Interval semantics and first-schedule behavior in `OfflineAutosaveService`.
2. Consent key handling (`cloud_sync` and `parental_control_cloud_sync_consent`) for backward compatibility.
3. Snapshot isolation correctness (queued snapshot should not mutate with later project edits).
4. Bounded queue behavior under repeated scheduling.

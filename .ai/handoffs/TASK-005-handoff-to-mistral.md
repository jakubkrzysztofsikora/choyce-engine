# Handoff: TASK-005 → Mistral (Cross-Review)

## Summary of changes
Implemented filesystem outbound adapters for local project and asset persistence:
- `FilesystemProjectStore` (`ProjectStorePort`)
- `FilesystemAssetRepository` (`AssetRepositoryPort`)

Also expanded contract tests to include adapter-level checks for both implementations.

## Files created
- `src/adapters/outbound/filesystem_project_store.gd`
- `src/adapters/outbound/filesystem_asset_repository.gd`
- `tests/contracts/filesystem_project_store_adapter_contract_test.gd`
- `tests/contracts/filesystem_asset_repository_adapter_contract_test.gd`

## Files updated
- `tests/contracts/run_contract_tests.gd` (added adapter tests)
- `tests/contracts/README.md` (documented adapter coverage)
- `.ai/tasks/backlog.yaml` (`TASK-005` moved to `in_review`)

## Storage layout implemented
Per project:
- `projects/{project_id}/manifest.json`
- `projects/{project_id}/worlds/{world_id}.json`
- `projects/{project_id}/assets/`

Manifest fields include:
- core project metadata
- `world_ids`
- `asset_references`
- `format_version`

## Contract test results
Executed:
```bash
./scripts/run-contract-tests.sh
```
Result:
- `Contracts: 13`
- `Checks: 108`
- `Failed contracts: 0`

Note: abstract port tests intentionally emit `push_error(... not implemented)` logs; these are expected and do not indicate failure.

## Open risks and assumptions
1. `asset_references` extraction currently reads common keys (`asset_id`, `asset_ref`, `asset_ids`) from scene node properties. If future schemas encode asset links differently, extraction should be extended.
2. `FilesystemAssetRepository` supports asset IDs in formats:
   - `{project_id}/{asset_path}` (preferred)
   - `{project_id}:{asset_path}`
   - `{asset_path}` (stored under `shared/assets/`)
3. `load_project()` returns `null` when manifest does not exist, matching application service expectations.

## Review focus areas
1. Validate manifest and world JSON schema stability for upcoming tasks (`TASK-006`, `TASK-009`).
2. Validate adapter behavior for nested scene node trees and rule serialization round-trips.
3. Confirm asset ID normalization policy is strict enough for path traversal safety.

## Commands used for verification
```bash
godot4 --headless --path . --check-only --script src/adapters/outbound/filesystem_project_store.gd
godot4 --headless --path . --check-only --script src/adapters/outbound/filesystem_asset_repository.gd
godot4 --headless --path . --check-only --script tests/contracts/filesystem_project_store_adapter_contract_test.gd
godot4 --headless --path . --check-only --script tests/contracts/filesystem_asset_repository_adapter_contract_test.gd
./scripts/run-contract-tests.sh
```

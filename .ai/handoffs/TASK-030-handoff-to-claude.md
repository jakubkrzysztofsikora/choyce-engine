# TASK-030 Handoff: Publish Flow with Moderation Checks and Parent Approval Gates

## Owner
- `claude` (implementation)
- `codex` (cross-review)

## Backlog status
- `TASK-030` moved to `in_progress`

## Scope
Complete publishing workflow so publish requests are safety-gated and role-gated end to end: moderation checks, parent approval decision, and final family-library visibility transition.

## Acceptance criteria to satisfy
1. Publish flow enforces child-safe checks for text, visuals, and audio.
2. Parent approval is required before family library visibility changes.

## Existing building blocks
- Domain + ports:
  - `src/domain/publishing/publish_request.gd`
  - `src/domain/publishing/publishing_policy.gd`
  - `src/ports/inbound/publish_to_family_library_port.gd`
  - `src/ports/inbound/review_publish_request_port.gd`
  - `src/ports/inbound/unpublish_world_port.gd`
  - `src/ports/outbound/publish_store_port.gd`
- Services already present:
  - `src/application/publish_to_family_library_service.gd`
  - `src/application/review_publish_request_service.gd`
  - `src/application/unpublish_world_service.gd`
- UI shell hook point:
  - `src/adapters/inbound/scenes/library/library_shell.gd`

## Gaps to close
- Ensure moderation coverage includes publishable textual metadata plus generated visual/audio publishability signals.
- Ensure approval gate semantics are strict for kid-originated requests.
- Ensure event emission and state transitions are deterministic and auditable.
- Add/complete tests for full flow (request -> moderation outcome -> parent review -> published/unpublished).

## Suggested files to touch
- `src/application/publish_to_family_library_service.gd`
- `src/application/review_publish_request_service.gd`
- `src/application/unpublish_world_service.gd`
- `src/adapters/inbound/scenes/library/library_shell.gd`
- `src/adapters/inbound/scenes/library/library_shell.tscn`
- `data/localization/ui_pl.json`
- Add contract/integration tests under `tests/contracts/` and `tests/adapters/inbound/`

## Validation expectations
- Add automated tests that cover at minimum:
  - moderation rejection path
  - kid publish request requiring parent approval
  - parent approval resulting in visibility change
  - parent rejection/unpublish paths
- Run:
  - `./scripts/run-contract-tests.sh`
  - any targeted inbound adapter test runner added for publish UI flow

## Review focus (for codex)
1. Safety gates cover text + visual + audio publishability concerns.
2. Parent-approval requirement cannot be bypassed.
3. State machine and emitted events align with domain semantics.
4. Tests prove end-to-end behavior, not only happy path.

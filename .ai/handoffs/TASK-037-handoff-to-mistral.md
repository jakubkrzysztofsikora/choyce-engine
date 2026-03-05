# TASK-037 Handoff: Child-Safe Telemetry Dashboards (Status, Audit, AI Performance)

## Owner
- `mistral` (implementation)
- `codex` (cross-review)

## Backlog status
- `TASK-037` moved to `in_progress`

## Scope
Implement dashboard-ready read-model integration for kid status, parent audit timeline, and AI performance views, with explicit data minimization and no ad-tech identifiers.

## Acceptance criteria to satisfy
1. Read models power kid project status, parent audit timeline, and AI performance views.
2. Analytics excludes ad-tech identifiers and preserves data minimization requirements.

## Existing building blocks
- Read-model ports:
  - `src/ports/outbound/kid_status_read_model.gd`
  - `src/ports/outbound/parent_audit_read_model.gd`
  - `src/ports/outbound/ai_performance_read_model.gd`
- Existing adapters:
  - `src/adapters/kid_status_read_model_adapter.gd`
  - `src/adapters/outbound/parent_audit_read_model_adapter.gd`
  - `src/adapters/ai_performance_read_model_adapter.gd`
- Existing tests:
  - `tests/contracts/kid_status_read_model_contract_test.gd`
  - `tests/contracts/parent_audit_read_model_contract_test.gd`
  - `tests/contracts/ai_performance_read_model_contract_test.gd`

## Gaps to close
- Wire read models to parent/kid-facing dashboard surfaces in inbound adapters.
- Ensure event-driven updates populate views with useful, age-appropriate summaries.
- Enforce minimization in telemetry/read-model payloads (no unnecessary identifiers).
- Expand tests for minimization + dashboard contract behavior.

## Suggested files to touch
- `src/adapters/inbound/scenes/play/play_shell.gd` (kid/project status view hook)
- `src/adapters/inbound/scenes/parent/parent_zone_shell.gd` (parent audit + AI metrics surface)
- `src/adapters/ai_performance_read_model_adapter.gd`
- `src/adapters/kid_status_read_model_adapter.gd`
- `src/adapters/outbound/parent_audit_read_model_adapter.gd`
- `data/localization/ui_pl.json`
- Add adapter/integration tests in `tests/adapters/inbound/` and contract refinements in `tests/contracts/`

## Validation expectations
- Add automated checks for:
  - dashboard view data population
  - event-to-read-model update correctness
  - no ad-tech identifiers in output payloads
- Run:
  - `./scripts/run-contract-tests.sh`
  - targeted inbound adapter tests for dashboard rendering/binding

## Review focus (for codex)
1. Read-model outputs remain deterministic and minimal.
2. UI wiring uses ports/adapters cleanly (no domain leakage).
3. Parent audit + AI metrics are explainable and actionable.
4. Added tests cover both correctness and minimization constraints.

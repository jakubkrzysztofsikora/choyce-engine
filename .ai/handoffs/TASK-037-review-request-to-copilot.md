# TASK-037 Review Request (to Copilot)

Status: `in_review`
Owner: `codex`
Cross-reviewer: `copilot`

## Implemented
- `PlayShell` now renders kid status summary from `KidStatusReadModel`.
- `ParentZoneShell` now renders minimized dashboard summaries from `ParentAuditReadModel` and `AIPerformanceReadModel`.
- `InboundMain` wiring passes read-model ports into Play/Parent shells.
- Hardening update:
  - profile-isolated kid status read-model queries,
  - recursive ad-tech key redaction in kid/parent/AI dashboard payloads,
  - improved AI performance metrics (`failed_executions`, `avg_latency_ms`) and deterministic fallback,
  - dedicated inbound dashboard integration regression test.

## Files
- `src/adapters/inbound/main.gd`
- `src/adapters/inbound/scenes/play/play_shell.gd`
- `src/adapters/inbound/scenes/play/play_shell.tscn`
- `src/adapters/inbound/scenes/parent/parent_zone_shell.gd`
- `src/adapters/inbound/scenes/parent/parent_zone_shell.tscn`
- `data/localization/ui_pl.json`
- `src/adapters/kid_status_read_model_adapter.gd`
- `src/adapters/ai_performance_read_model_adapter.gd`
- `src/adapters/outbound/parent_audit_read_model_adapter.gd`
- `tests/contracts/kid_status_read_model_contract_test.gd`
- `tests/contracts/ai_performance_read_model_contract_test.gd`
- `tests/contracts/parent_audit_read_model_adapter_contract_test.gd`
- `tests/adapters/inbound/test_dashboard_read_models_integration.gd`
- `scripts/ci/run-inbound-shell-regression.sh`

## Validation
- `./scripts/ci/run-inbound-shell-regression.sh`
- `./scripts/run-contract-tests.sh`
- `./scripts/run-quality-gates.sh`

Please confirm UX copy, data minimization, and role-safe visibility behavior.

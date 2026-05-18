# Handoff: TASK-037 Hardening Update -> Copilot (Cross-Review)

## Summary
Applied a hardening pass for child-safe telemetry dashboards with stronger data minimization guarantees and explicit inbound dashboard integration coverage.

## Files updated
- `src/adapters/kid_status_read_model_adapter.gd`
- `src/adapters/ai_performance_read_model_adapter.gd`
- `src/adapters/outbound/parent_audit_read_model_adapter.gd`
- `tests/contracts/kid_status_read_model_contract_test.gd`
- `tests/contracts/ai_performance_read_model_contract_test.gd`
- `tests/contracts/parent_audit_read_model_adapter_contract_test.gd`
- `tests/adapters/inbound/test_dashboard_read_models_integration.gd`
- `scripts/ci/run-inbound-shell-regression.sh`

## Hardening changes
1. `KidStatusReadModelAdapter`
- Added profile isolation gate for `get_project_status` and `list_recent_projects`.
- Added ad-tech key redaction in read-model payloads.
- Added profile ownership enrichment from event metadata (`profile_id`, `actor_id`, `child_id`).

2. `AIPerformanceReadModelAdapter`
- Added failed execution and average latency accumulation logic.
- Added deterministic fallback for missing tool names (`unknown_tool`).
- Added ad-tech key redaction for metrics and tool-stat outputs.

3. `ParentAuditReadModelAdapter` (outbound/canonical)
- Added payload sanitization before returning timeline/intervention records.
- Added recursive ad-tech key redaction for nested payload dictionaries/arrays.

4. Test coverage
- Added integration test for Play/Parent dashboard read-model wiring and sanitization:
  - `tests/adapters/inbound/test_dashboard_read_models_integration.gd`
- Expanded contract tests with minimization/isolation assertions for all 3 read models.
- Updated inbound regression runner to execute the new dashboard integration test.

## Validation
Executed locally:
```bash
./scripts/ci/run-inbound-shell-regression.sh
./scripts/run-contract-tests.sh
./scripts/run-quality-gates.sh
```

Observed:
- all commands exit `0`
- dashboard integration test passes
- contract suite passes with strengthened checks
- quality gates remain green

## Review focus
1. Confirm profile-isolation policy in kid status model matches expected family visibility boundaries.
2. Confirm ad-tech redaction key patterns are sufficient for policy baseline.
3. Confirm parent audit sanitization strategy is acceptable for downstream timeline consumers.

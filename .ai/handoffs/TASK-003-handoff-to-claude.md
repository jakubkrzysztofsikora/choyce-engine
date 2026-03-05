# Handoff: TASK-003 → Claude (Cross-Review)

## Summary of changes
Implemented all required outbound port interfaces under `src/ports/outbound/` and added a contract test harness in `tests/contracts/` with one concrete contract test per port plus a single runner script.

## Files created

### Outbound port interfaces
- `src/ports/outbound/llm_port.gd`
- `src/ports/outbound/moderation_port.gd`
- `src/ports/outbound/speech_to_text_port.gd`
- `src/ports/outbound/text_to_speech_port.gd`
- `src/ports/outbound/audio_generation_port.gd`
- `src/ports/outbound/asset_repository_port.gd`
- `src/ports/outbound/project_store_port.gd`
- `src/ports/outbound/telemetry_port.gd`
- `src/ports/outbound/clock_port.gd`
- `src/ports/outbound/identity_consent_port.gd`
- `src/ports/outbound/localization_policy_port.gd`

### Contract test harness
- `tests/contracts/port_contract_test.gd` (base assertions)
- `tests/contracts/run_contract_tests.gd` (runner)
- `tests/contracts/README.md` (usage)
- `tests/contracts/llm_port_contract_test.gd`
- `tests/contracts/moderation_port_contract_test.gd`
- `tests/contracts/speech_to_text_port_contract_test.gd`
- `tests/contracts/text_to_speech_port_contract_test.gd`
- `tests/contracts/audio_generation_port_contract_test.gd`
- `tests/contracts/asset_repository_port_contract_test.gd`
- `tests/contracts/project_store_port_contract_test.gd`
- `tests/contracts/telemetry_port_contract_test.gd`
- `tests/contracts/clock_port_contract_test.gd`
- `tests/contracts/identity_consent_port_contract_test.gd`
- `tests/contracts/localization_policy_port_contract_test.gd`
- `scripts/run-contract-tests.sh` (bootstrap + run helper)
- `project.godot` (minimal project config for `res://` resolution and class registration)

## Task status
- Updated `.ai/tasks/backlog.yaml` for `TASK-003` from `in_progress` to `in_review`.

## Open risks and assumptions
1. Base port methods intentionally call `push_error("... not implemented")`, so contract runs are expected to print error logs while still passing type/shape checks.
2. Some null-input checks rely on GDScript object-type nullability behavior at runtime.

## Review focus areas
1. Confirm fallback return values align with expected safety defaults for each port (`false`/empty vs object placeholders).
2. Validate that null/empty input checks in contract tests are consistent with intended runtime behavior.
3. Confirm no outbound port leaks adapter/runtime concerns beyond `RefCounted` and value/object types.

## Commands used for verification
```bash
rg --files src/ports/outbound tests/contracts | sort
rg -n "extends (Node|Control|Node2D|Node3D)" src/ports/outbound tests/contracts || true
rg -n "push_error\\(" src/ports/outbound | sort
./scripts/run-contract-tests.sh
```

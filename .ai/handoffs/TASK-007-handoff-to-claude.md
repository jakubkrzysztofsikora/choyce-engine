# Handoff: TASK-007 → Claude (Cross-Review)

## Summary of changes
Implemented the four utility outbound adapters required by TASK-007 and added adapter contract coverage:
- `SystemClock` (`ClockPort`)
- `LocalTelemetry` (`TelemetryPort`)
- `LocalConsentStore` (`IdentityConsentPort`)
- `PolishLocalizationPolicy` (`LocalizationPolicyPort`)

Also added Polish localization seed files used by the localization policy adapter.

## Files created
- `src/adapters/outbound/system_clock.gd`
- `src/adapters/outbound/local_telemetry.gd`
- `src/adapters/outbound/local_consent_store.gd`
- `src/adapters/outbound/polish_localization_policy.gd`
- `data/localization/ui_pl.json`
- `data/localization/glossary_kid_pl.json`
- `tests/contracts/system_clock_adapter_contract_test.gd`
- `tests/contracts/local_telemetry_adapter_contract_test.gd`
- `tests/contracts/local_consent_store_adapter_contract_test.gd`
- `tests/contracts/polish_localization_policy_adapter_contract_test.gd`

## Files updated
- `tests/contracts/run_contract_tests.gd` (added 4 adapter tests)
- `tests/contracts/README.md` (documented new adapter coverage)
- `.ai/tasks/backlog.yaml` (`TASK-007` moved to `in_review`)

## Behavior notes
1. `SystemClock` returns ISO timestamp and UNIX milliseconds.
2. `LocalTelemetry` writes JSONL under `user://telemetry/events.jsonl` and strips ad-tech/tracking keys recursively.
3. `LocalConsentStore` persists per-profile consent decisions in `user://consent/consents.json` and defaults to deny (`false`).
4. `PolishLocalizationPolicy` defaults locale to `pl-PL`, loads optional translation/glossary JSON resources, enforces blocked terms, and provides preferred term mapping.

## Verification
Executed:
```bash
./scripts/run-contract-tests.sh
```
Result:
- `Contracts: 17`
- `Checks: 154`
- `Failed contracts: 0`

Also checked individual scripts with `godot4 --check-only` for all new adapters and tests.

## Open risks and assumptions
1. Telemetry key filtering is pattern-based and intentionally conservative; false positives are possible for similarly named keys.
2. Localization files are seeded with ASCII Polish approximations in this pass; richer localization assets can extend these files later.
3. `PolishLocalizationPolicy` currently falls back to in-code defaults if `res://data/localization/*.json` are unavailable.

## Review focus areas
1. Confirm telemetry sanitization policy sufficiently matches child-safe analytics constraints.
2. Confirm consent persistence behavior aligns with parent approval workflows expected in future tasks.
3. Validate localization policy defaults and glossary behavior against TR-L10N requirements.

## Commands used
```bash
godot4 --headless --path . --check-only --script src/adapters/outbound/system_clock.gd
godot4 --headless --path . --check-only --script src/adapters/outbound/local_telemetry.gd
godot4 --headless --path . --check-only --script src/adapters/outbound/local_consent_store.gd
godot4 --headless --path . --check-only --script src/adapters/outbound/polish_localization_policy.gd
godot4 --headless --path . --check-only --script tests/contracts/system_clock_adapter_contract_test.gd
godot4 --headless --path . --check-only --script tests/contracts/local_telemetry_adapter_contract_test.gd
godot4 --headless --path . --check-only --script tests/contracts/local_consent_store_adapter_contract_test.gd
godot4 --headless --path . --check-only --script tests/contracts/polish_localization_policy_adapter_contract_test.gd
./scripts/run-contract-tests.sh
```

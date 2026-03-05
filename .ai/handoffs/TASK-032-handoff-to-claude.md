# Handoff: TASK-032 -> Claude (Cross-Review)

## Summary of changes
Completed Polish-first language policy wiring for AI text and voice paths, including explicit parent language override gating through parental policy controls.

### What was already in place and validated in this handoff
1. Added policy service:
- `src/application/polish_first_language_policy_service.gd`
- Behavior:
  - Kid profile locale is always `pl-PL`.
  - Parent non-Polish locale is allowed only when `ParentalControlPolicy.language_override_allowed == true`.

2. Integrated policy into AI text prompt wrappers:
- `src/application/request_ai_creation_help_service.gd`
- `src/application/request_gameplay_hint_service.gd`
- Both services now resolve locale via `PolishFirstLanguagePolicyService` (or fallback to localization policy if no language-policy dependency is provided).

### Newly completed in this pass
3. Wired voice governance to parental language policy controls:
- `src/application/audio_governance_service.gd`
  - Added optional dependencies:
    - `ParentalPolicyStorePort`
    - `PolishFirstLanguagePolicyService`
  - Voice locale resolution now uses policy service (kid forced Polish, parent override-controlled).
  - Added `_is_parent_override_enabled(...)` with backward compatibility for legacy profile preferences.
  - Metadata language now stays Polish by default and only switches for parent when policy override is enabled.

4. Added explicit override metadata in TTS adapter:
- `src/adapters/outbound/elevenlabs_tts_adapter.gd`
  - `get_last_request_metadata()` payload now includes `allow_language_override`.

5. Expanded contracts for voice override behavior:
- `tests/contracts/audio_governance_service_contract_test.gd`
  - New checks verify:
    - parent with policy override can use non-Polish voice locale,
    - kid remains Polish even when parent override exists.

6. Added focused TASK-032 contract runner:
- `tests/contracts/run_task_032_tests.gd`

7. Updated contracts documentation:
- `tests/contracts/README.md`

## Files touched
- `src/application/polish_first_language_policy_service.gd`
- `src/application/request_ai_creation_help_service.gd`
- `src/application/request_gameplay_hint_service.gd`
- `src/application/audio_governance_service.gd`
- `src/adapters/outbound/elevenlabs_tts_adapter.gd`
- `tests/contracts/polish_first_language_policy_service_contract_test.gd`
- `tests/contracts/request_ai_creation_help_service_contract_test.gd`
- `tests/contracts/request_gameplay_hint_service_contract_test.gd`
- `tests/contracts/audio_governance_service_contract_test.gd`
- `tests/contracts/run_task_032_tests.gd`
- `tests/contracts/README.md`

## Validation
Executed:
```bash
godot4 --headless --path . --script tests/contracts/run_task_032_tests.gd
```

Result:
- `Tests: 4`
- `Checks: 45`
- `Failed tests: 0`

Passing suites:
- `PolishFirstLanguagePolicyService`
- `RequestGameplayHintService`
- `RequestAICreationHelpService`
- `AudioGovernanceService`

## Acceptance criteria mapping
1. Kid and parent AI interactions default to Polish text and voice output:
- Kid text prompts in creation/hint flows are forced to `pl-PL`.
- Voice governance path enforces Polish by default.

2. Parent override can switch language while preserving kid-mode safety defaults:
- Parent non-Polish locale is enabled only with `language_override_allowed` parental policy.
- Kid path remains Polish even when parent override is enabled.

## Review focus areas
1. Confirm policy-wired locale logic is consistent across text and voice paths.
2. Confirm no bypass exists for kid non-Polish locale.
3. Confirm backward compatibility path in audio governance (`actor.preferences`) is acceptable.
4. Confirm test coverage is sufficient for both default and override scenarios.

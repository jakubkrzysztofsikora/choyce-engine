# Handoff: TASK-016 -> Claude (Cross-Review)

## Summary of changes
Implemented ElevenLabs-style TTS/audio adapters and an application governance layer that enforces consent, moderation, and license gates before playback/publish eligibility.

### New outbound adapters
1. `ElevenLabsTTSAdapter` (`TextToSpeechPort`)
- Added Polish-first role presets for narration and NPC voice.
- Enforces Polish defaults unless explicit parent override setting is present.
- Exposes request metadata (`license_id`, `attribution`, `voice_preset`, `language`) for governance checks.

2. `ElevenLabsAudioGenerationAdapter` (`AudioGenerationPort`)
- Added child-safe ambient generation for `sfx` and `music`.
- Defaults to non-lyrical output (`bez wokalu`) and Polish metadata.
- Exposes generation metadata required for license/publish decisions.

### New application service
3. `AudioGovernanceService`
- Consent gate: blocks kid audio generation without `cloud_audio_generation` (or legacy `cloud_tts`) consent.
- Moderation gate: blocks unsafe text descriptions before generation.
- Licensing gate: blocks playback/publish when metadata license/attribution is missing or unapproved.
- Metadata tagging: adds AI watermark/tag fields and playback/publish flags in returned payload.
- Emits `SafetyInterventionTriggered` events when governance blocks are triggered.

## Files created
- `src/adapters/outbound/elevenlabs_tts_adapter.gd`
- `src/adapters/outbound/elevenlabs_audio_generation_adapter.gd`
- `src/application/audio_governance_service.gd`
- `tests/contracts/elevenlabs_tts_adapter_contract_test.gd`
- `tests/contracts/elevenlabs_audio_generation_adapter_contract_test.gd`
- `tests/contracts/audio_governance_service_contract_test.gd`
- `.ai/handoffs/TASK-016-handoff-to-claude.md`

## Files updated
- `tests/contracts/run_contract_tests.gd`
- `tests/contracts/README.md`
- `.ai/tasks/backlog.yaml` (`TASK-016` -> `in_review` after handoff)

## Verification
Executed:
```bash
./scripts/run-contract-tests.sh
```

Result:
- `Contracts: 38`
- `Checks: 435`
- `Failed contracts: 0`

New passing contracts:
- `ElevenLabsTTSAdapter` (12 checks)
- `ElevenLabsAudioGenerationAdapter` (14 checks)
- `AudioGovernanceService` (13 checks)

## Acceptance criteria mapping
1. Polish voice presets are enforced by default for narration and NPC generation:
- `ElevenLabsTTSAdapter` resolves narration/NPC roles to approved Polish presets.
- Contract test verifies non-Polish request still resolves to `pl-PL` default behavior.

2. Audio moderation and licensing checks gate playback and publishing:
- `AudioGovernanceService` enforces moderation before synthesis/generation.
- Licensing metadata is validated against approved IDs and requires attribution.
- Result payload explicitly returns `playback_allowed` and `publish_allowed` flags only when checks pass.

## Review focus areas
1. Validate consent gate semantics for kid profile flow (including legacy consent compatibility).
2. Validate license gating behavior and metadata requirements for publish eligibility.
3. Validate that Polish-first defaults are correctly enforced without violating hex boundaries.

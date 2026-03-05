Please review TASK-016 implementation in:
- src/adapters/outbound/elevenlabs_tts_adapter.gd
- src/adapters/outbound/elevenlabs_audio_generation_adapter.gd
- src/application/audio_governance_service.gd
- tests/contracts/elevenlabs_tts_adapter_contract_test.gd
- tests/contracts/elevenlabs_audio_generation_adapter_contract_test.gd
- tests/contracts/audio_governance_service_contract_test.gd

Handoff details:
- .ai/handoffs/TASK-016-handoff-to-claude.md

Acceptance targets:
1. Polish voice presets are enforced by default for narration and NPC voice generation.
2. Audio moderation and licensing checks gate playback and publishing decisions.

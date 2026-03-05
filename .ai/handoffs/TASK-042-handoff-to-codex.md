# TASK-042 Handoff: Voice Input Moderation & Transcript Safety Gating

## Implementer: claude (Architecture & Review Specialist)
## Cross-reviewer: codex

---

## Summary

Implemented `VoiceInputModerationService` — an application service that orchestrates the full voice safety pipeline: transcribe → moderate → extract intent. Blocks unsafe transcripts with explainable safe alternatives and emits `SafetyInterventionTriggeredEvent` to the audit trail.

---

## Files Created (2)

| File | Type | Purpose |
|------|------|---------|
| `src/application/voice_input_moderation_service.gd` | Application Service | Orchestrates STT → moderation → intent extraction; emits safety events |
| `tests/contracts/voice_input_moderation_service_contract_test.gd` | Contract Test | 29 checks covering: empty audio, safe/unsafe transcripts, safety events, null actor, optional deps |

## Files Updated (2)

| File | Changes |
|------|---------|
| `tests/contracts/run_contract_tests.gd` | Added VoiceInputModerationService test registration |
| `src/domain/CONTEXT_MAP.md` | Added voice input safety gating to Identity & Safety responsibilities |

---

## Verification

```
Contracts: 51  Checks: 651  Failed contracts: 0
```

All 51 contracts pass including 1 new one (29 checks for TASK-042).

---

## Architecture

### Flow
```
Audio (PackedByteArray) + PlayerProfile
    ↓
Step 1: SpeechToTextPort.transcribe(audio, "pl-PL")
    → Empty result? Return {allowed: false, reason: "TRANSCRIPTION_FAILED"}
    ↓
Step 2: ModerationPort.check_text(transcript, actor.age_band)
    → BLOCK? Emit SafetyInterventionTriggeredEvent, return safe alternative
    → WARN? Pass through (log but allow)
    ↓
Step 3: IntentExtractor.extract_intent(transcript)
    ↓
Return {allowed: true, transcript, intent, moderation_verdict}
```

### Dependencies
- **SpeechToTextPort** (required) — transcription via local-first chain
- **ModerationPort** (required) — text moderation with age-band awareness
- **IntentExtractor** (optional, RefCounted) — duck-typed, expects `extract_intent(String) -> String`
- **DomainEventBus** (optional) — safety event emission
- **ClockPort** (optional) — timestamps for events

### Design Decisions
1. **Duck-typed intent extractor**: Uses `RefCounted` + `has_method("extract_intent")` instead of `PolishIntentExtractor` type. This decouples from the specific extractor implementation and avoids compile-time coupling.
2. **Local-first**: STT transcription delegates to SpeechToTextPort which (via STTFallbackChain) tries local first, cloud as consent-gated fallback.
3. **Polish-first safe alternatives**: Default fallback is "Spróbuj powiedzieć coś innego!" when moderation doesn't provide a specific alternative.
4. **[VOICE] prefix**: Safety event trigger_context prefixed with `[VOICE]` to distinguish voice-originating blocks in parent audit timeline.
5. **Decision ID**: `voice_{hash}_{timestamp_msec}` for uniqueness (uses clock.now_msec to avoid collision).

---

## Acceptance Criteria

### 1. "STT transcripts are moderated before intent execution and unsafe input is blocked with safe alternatives"
- Moderation runs on raw transcript BEFORE intent extraction
- BLOCK verdict returns `{allowed: false, safe_alternative: ...}`
- 29 test checks verify safe/unsafe paths

### 2. "Local-first transcription path is preferred and cloud fallback remains consent-gated"
- Service accepts SpeechToTextPort — when wired with STTFallbackChain, local-first is automatic
- CloudSTTAdapter (TASK-017) enforces consent check internally

### 3. "Voice safety interventions are emitted to audit events with explainable reasons"
- SafetyInterventionTriggeredEvent emitted with:
  - `policy_rule`: "VOICE_TRANSCRIPT_MODERATION_BLOCK"
  - `trigger_context`: "[VOICE] <transcript>"
  - `decision_type`: "BLOCK"
  - `safe_alternative_offered`: true/false
- Events flow to DomainEventBus → AuditLedger → parent timeline

---

## Review Focus Areas

1. **Duck-typed intent extractor** — verify `has_method("extract_intent")` is sufficient and doesn't break with real PolishIntentExtractor
2. **Event emission** — verify decision_id uniqueness strategy (hash + timestamp)
3. **WARN handling** — currently passes through without event emission; verify this is acceptable
4. **Result dictionary shape** — all 7 keys always present for consistent downstream consumption

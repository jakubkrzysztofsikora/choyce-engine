# Codex Execution Prompt — Wave 1–2 Tasks

## Context
TASK-001 is complete. The domain model is defined in `src/domain/` with 5 bounded contexts, 8 entities, 5 value objects, and 6 domain events — all as framework-agnostic GDScript classes extending `RefCounted`.

Read these before starting:
- `src/ARCHITECTURE.md` — hexagonal rules and port interface patterns
- `src/domain/CONTEXT_MAP.md` — bounded context boundaries and relationships
- `.ai/handoffs/TASK-001-handoff-to-codex.md` — full file listing and review notes

---

## TASK-003: Implement outbound ports and contract test harness
**Priority: Start immediately (no blockers)**

### Objective
Define the 11 outbound port interfaces in `src/ports/outbound/` and scaffold a contract test harness.

### Port interfaces to create
Each port must be an abstract GDScript class extending `RefCounted` with methods that `push_error("not implemented")` as default. Follow the pattern in `src/ARCHITECTURE.md`.

| Port | File | Key methods |
|---|---|---|
| LLMPort | `llm_port.gd` | `complete(envelope: PromptEnvelope) -> String`, `complete_with_tools(envelope: PromptEnvelope) -> Array[ToolInvocation]` |
| ModerationPort | `moderation_port.gd` | `check_text(text: String, age_band: AgeBand) -> ModerationResult`, `check_image(image_data: PackedByteArray, age_band: AgeBand) -> ModerationResult` |
| SpeechToTextPort | `speech_to_text_port.gd` | `transcribe(audio: PackedByteArray, language: String) -> String` |
| TextToSpeechPort | `text_to_speech_port.gd` | `synthesize(text: String, voice_id: String, language: String) -> PackedByteArray` |
| AudioGenerationPort | `audio_generation_port.gd` | `generate_sfx(description: String) -> PackedByteArray`, `generate_music(description: String) -> PackedByteArray` |
| AssetRepositoryPort | `asset_repository_port.gd` | `store(asset_id: String, data: PackedByteArray) -> bool`, `load(asset_id: String) -> PackedByteArray`, `exists(asset_id: String) -> bool` |
| ProjectStorePort | `project_store_port.gd` | `save_project(project: Project) -> bool`, `load_project(project_id: String) -> Project`, `list_projects() -> Array` |
| TelemetryPort | `telemetry_port.gd` | `emit_event(event_name: String, properties: Dictionary) -> void` |
| ClockPort | `clock_port.gd` | `now_iso() -> String`, `now_msec() -> int` |
| IdentityConsentPort | `identity_consent_port.gd` | `has_consent(profile_id: String, consent_type: String) -> bool`, `request_consent(profile_id: String, consent_type: String) -> bool` |
| LocalizationPolicyPort | `localization_policy_port.gd` | `get_locale() -> String`, `translate(key: String) -> String`, `is_term_safe(term: String) -> bool` |

### Contract test harness
Create `tests/contracts/` with:
1. A base `PortContractTest` class that verifies: method exists, returns correct type, handles null/empty gracefully.
2. One concrete contract test per port (can be a template/generator pattern).
3. Test runner instructions in `tests/contracts/README.md`.

### Acceptance criteria
- All 11 outbound port interfaces defined with stable contracts
- Contract tests exist for each port-adapter pair scaffold
- Zero imports from Godot Node/scene/physics APIs in port files

---

## TASK-005: Implement local project format and filesystem storage adapters
**Blocked by: TASK-003**

### Objective
Implement `ProjectStorePort` and `AssetRepositoryPort` filesystem adapters.

### Requirements (from TR-DATA-001)
- Project format: JSON metadata + binary assets + manifest file
- Directory layout per project: `projects/{project_id}/manifest.json`, `projects/{project_id}/worlds/`, `projects/{project_id}/assets/`
- Manifest includes project metadata, world list, asset references

### Files to create
- `src/adapters/outbound/filesystem_project_store.gd` — implements ProjectStorePort
- `src/adapters/outbound/filesystem_asset_repository.gd` — implements AssetRepositoryPort
- Contract tests must pass for both adapters

---

## TASK-007: Implement core utility adapters
**Blocked by: TASK-003**

### Objective
Wire `IdentityConsentPort`, `ClockPort`, `TelemetryPort`, and `LocalizationPolicyPort` adapters.

### Requirements
- `ClockPort` adapter: wraps system time, returns ISO 8601 strings
- `TelemetryPort` adapter: local-only event logger (no ad-tech identifiers, per TR-INT-004)
- `IdentityConsentPort` adapter: local consent store (file-based)
- `LocalizationPolicyPort` adapter: defaults to `pl-PL`, loads glossary, enforces child-safe wording (per TR-L10N-001, TR-L10N-005)

### Files to create
- `src/adapters/outbound/system_clock.gd`
- `src/adapters/outbound/local_telemetry.gd`
- `src/adapters/outbound/local_consent_store.gd`
- `src/adapters/outbound/polish_localization_policy.gd`

---

## TASK-011: Implement Ollama LLM adapter with model catalog and fallback chain
**Blocked by: TASK-003**

### Objective
Implement `LLMPort` adapter for Ollama with model selection and consent-gated cloud fallback.

### Requirements (from TR-AI-001, TR-AI-002)
- Model catalog: small (intent/hints), medium (code/planning), optional multimodal
- Tool-calling contract: send `ToolInvocation` schemas, parse structured responses
- Fallback: small → medium → optional cloud (only with parent consent via IdentityConsentPort)
- Polish prompt injection via `PromptEnvelope.language`

### Files to create
- `src/adapters/outbound/ollama_llm_adapter.gd` — implements LLMPort
- `src/adapters/outbound/ollama_model_catalog.gd` — model registry with tier mapping

---

## TASK-004: Implement domain event bus and CQRS-lite read model interfaces
**Blocked by: TASK-001 (done), TASK-002 (claude, pending)**

### Objective
Build the in-domain event bus that routes `DomainEvent` subclasses to subscribers, and define read model interfaces for kid status, parent audit, and AI performance views.

### Key decisions
- Event bus should be a singleton-like service (not a Godot Node autoload — keep it domain-pure)
- Read model interfaces are outbound ports (query side)
- Events already defined in `src/domain/events/` — bus must handle all 5 event types

### Files to create
- `src/domain/events/event_bus.gd` — subscribe/emit pattern
- `src/ports/outbound/kid_status_read_model.gd`
- `src/ports/outbound/parent_audit_read_model.gd`
- `src/ports/outbound/ai_performance_read_model.gd`

---

## Execution order
```
TASK-003 (start now, no blockers)
    ├── TASK-005 (after TASK-003)
    ├── TASK-007 (after TASK-003)
    └── TASK-011 (after TASK-003)
TASK-004 (after TASK-002 completes — coordinate with claude)
```

## Cross-review
- TASK-003 reviewed by: claude
- TASK-004 reviewed by: claude
- TASK-005 reviewed by: mistral
- TASK-007 reviewed by: claude
- TASK-011 reviewed by: claude

Submit each task as a separate PR for focused review.

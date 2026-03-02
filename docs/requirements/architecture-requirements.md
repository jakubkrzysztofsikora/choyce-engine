# Architecture Requirements (Hexagonal)

## 1) Architectural style mandate
The platform MUST use **hexagonal architecture (ports and adapters)** so domain logic is isolated from engines, AI vendors, UI channels, and data stores.

Core principle:
- Domain is pure and testable.
- External systems (Godot runtime, Ollama, DB, voice APIs, moderation services) are adapters plugged through ports.

---

## 2) High-level bounded contexts
- **World Authoring Context**: scenes, assets, rules, templates.
- **Gameplay Context**: sessions, progression, quests, economy.
- **AI Orchestration Context**: planning, tool execution, safety policy, memory.
- **Identity & Safety Context**: child/parent roles, consent, moderation, controls.
- **Publishing Context**: packaging, review, family sharing.

---

## 3) Core domain model (minimum)
- Entities:
  - Project
  - World
  - SceneNode
  - GameRule
  - Session
  - PlayerProfile (Kid, Parent)
  - AIAssistantAction
  - SafetyPolicyDecision
- Value Objects:
  - AgeBand
  - PromptEnvelope
  - ToolInvocation
  - ModerationResult
  - ProgressState

---

## 4) Required inbound ports (use-cases)
- `CreateProjectFromTemplate`
- `ApplyWorldEditCommand`
- `CompileBlockLogicToRules`
- `RunPlaytest`
- `RequestAICreationHelp`
- `RequestGameplayHint`
- `ApproveAIPatch`
- `PublishToFamilyLibrary`
- `SetParentalControls`

Each use-case MUST be independent of concrete UI/runtime frameworks.

---

## 5) Required outbound ports
- `LLMPort` (chat, tool-call, embeddings optional)
- `ModerationPort`
- `SpeechToTextPort`
- `TextToSpeechPort`
- `AudioGenerationPort` (SFX/music generation with policy checks)
- `AssetRepositoryPort`
- `ProjectStorePort`
- `TelemetryPort`
- `ClockPort`
- `IdentityConsentPort`

Adapters can be swapped without changing use-case implementations.

---

## 6) Adapter examples

## 6.1 Inbound adapters
- Godot editor plugin UI adapter
- Child play UI adapter
- Parent dashboard adapter
- Voice command adapter

## 6.2 Outbound adapters
- Ollama HTTP adapter for `LLMPort`
- Local rules+ML moderation adapter for `ModerationPort`
- Filesystem adapter for local project storage
- Cloud sync adapter (optional)
- ElevenLabs adapter for `TextToSpeechPort` and `AudioGenerationPort`

---

## 7) AI orchestration architecture
Use an **agent loop with deterministic tools**:
1. Receive intent/event.
2. Policy pre-check (role, age, safety).
3. Ask model to propose plan + tool calls.
4. Validate tool calls against schema and permissions.
5. Execute tools transactionally.
6. Policy post-check + explanation generation.
7. Emit audit event.

Requirements:
- AR-AI-001: Tool execution must be idempotent when possible.
- AR-AI-002: Every AI-applied mutation must have reversible patch.
- AR-AI-003: Human approval gate for high-impact actions.

---

## 8) Data flow and eventing
- Event bus inside domain boundary for significant events:
  - `WorldEdited`
  - `RuleChanged`
  - `AIAssistanceRequested`
  - `AIAssistanceApplied`
  - `SafetyInterventionTriggered`
- CQRS-lite read models for:
  - kid-friendly project status view
  - parent audit timeline
  - AI performance dashboard

---

## 9) Safety architecture requirements
- AR-SAFE-001: Dual-filter moderation (input + output).
- AR-SAFE-002: Age-aware prompt templates.
- AR-SAFE-003: Restricted tool scopes in kid mode.
- AR-SAFE-004: Parent override logging with reason.
- AR-SAFE-005: Failsafe mode: disable generative output but keep core editor functional.
- AR-SAFE-006: AI-generated audio (voice/music/SFX) must pass moderation and license checks prior to runtime playback and publishing.

---

## 10) Extensibility requirements
- AR-EXT-001: Plugin SDK for new game mechanics through declared ports.
- AR-EXT-002: Template packs as data, not hardcoded logic.
- AR-EXT-003: Model provider abstraction (Ollama default; others optional via adapter).

---

## 11) Deployment views
- Local-only mode (single device, full privacy, no social publish).
- Family cloud mode (sync, private sharing, managed backups).
- Classroom mode (managed policies + curriculum templates).

---

## 12) Architecture quality gates
- 90%+ of domain tests run without engine runtime or network.
- Contract tests for each port/adapter pair.
- Threat modeling updates per release.
- AI regression pack must pass before enabling new model versions.

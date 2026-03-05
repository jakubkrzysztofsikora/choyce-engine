# Bounded Context Map

## Contexts and their responsibilities

### 1. World Authoring (src/domain/world_authoring/)
- **Owns**: Project, World, SceneNode, GameRule
- **Responsibility**: scene graph management, template instantiation, rule compilation, asset references
- **Upstream of**: Gameplay (provides world definitions), Publishing (provides publishable content)

### 2. Gameplay (src/domain/gameplay/)
- **Owns**: Session, PlayerProfile, ProgressState
- **Responsibility**: session lifecycle, player progression, quest tracking, co-op coordination
- **Depends on**: World Authoring (reads world/rule definitions)

### 3. AI Orchestration (src/domain/ai_orchestration/)
- **Owns**: AIAssistantAction
- **Uses shared**: PromptEnvelope, ToolInvocation
- **Responsibility**: intent interpretation, tool planning, policy-gated execution, explanation generation
- **Depends on**: Identity & Safety (pre/post policy checks), World Authoring (scene/rule mutations)

### 4. Identity & Safety (src/domain/identity_safety/)
- **Owns**: SafetyPolicyDecision, ParentalControlPolicy, RoleToken
- **Uses shared**: AgeBand, ModerationResult
- **Responsibility**: role/age policy enforcement, content moderation, parental controls, audit decisions, voice input safety gating, cryptographic role verification
- **Upstream of**: AI Orchestration (policy gates), Publishing (moderation prerequisites)

### 5. Publishing (src/domain/publishing/)
- **Owns**: PublishRequest, PublishingPolicy
- **Responsibility**: publish workflow state machine, visibility control, parent approval, moderation gating, unpublish
- **Depends on**: World Authoring (content to publish), Identity & Safety (moderation checks)
- **State machine**: DRAFT → MODERATION_PASSED → PENDING_REVIEW → APPROVED → PUBLISHED (→ UNPUBLISHED → DRAFT via revise)

## Shared Kernel (src/domain/shared/)
Value objects used across multiple contexts:
- **AgeBand** — age tier for policy decisions (Identity & Safety, AI Orchestration, Gameplay)
- **PromptEnvelope** — AI prompt with safety/l10n metadata (AI Orchestration)
- **ToolInvocation** — AI tool call description (AI Orchestration)
- **ModerationResult** — content check outcome (Identity & Safety, Publishing)
- **ProgressState** — session progression snapshot (Gameplay)
- **WorldEditCommand** — scene graph edit descriptor (World Authoring)
- **AuditRecord** — tamper-evident audit ledger entry with hash chain (Identity & Safety, cross-cutting)
- **ManifestSignature** — HMAC-SHA256 plugin manifest signature (Publishing, extensibility)
- **PluginManifest** — plugin capability declaration with cryptographic signing (extensibility)

## Domain Events (src/domain/events/)
Cross-cutting events emitted by contexts:
- **WorldEditedEvent** — from World Authoring
- **RuleChangedEvent** — from World Authoring
- **AIAssistanceRequestedEvent** — from AI Orchestration
- **AIAssistanceAppliedEvent** — from AI Orchestration
- **SafetyInterventionTriggeredEvent** — from Identity & Safety
- **ParentalPolicyUpdatedEvent** — from Identity & Safety
- **PublishRequestSubmittedEvent** — from Publishing
- **PublishApprovedEvent** — from Publishing
- **PublishRejectedEvent** — from Publishing
- **WorldPublishedEvent** — from Publishing
- **WorldUnpublishedEvent** — from Publishing

## Context relationships
```
Identity & Safety ──policy gates──▶ AI Orchestration
       │                                │
       │ moderation                     │ mutations
       ▼                                ▼
   Publishing ◀──content──── World Authoring
                                        │
                                        │ world defs
                                        ▼
                                    Gameplay
```

## Event Infrastructure (TASK-004, done)
- **DomainEventBus** (src/domain/events/event_bus.gd) — in-domain pub/sub, type-filtered subscriptions, capped history

## Port boundary (defined in TASK-002 / TASK-003)
- Inbound ports (use-cases): src/ports/inbound/
- Outbound ports (external service contracts): src/ports/outbound/
- Adapters (Godot, Ollama, filesystem, etc.): src/adapters/

## Implemented adapters
| Adapter | Port | Task |
|---|---|---|
| FilesystemProjectStore | ProjectStorePort | TASK-005 |
| FilesystemAssetRepository | AssetRepositoryPort | TASK-005 |
| SystemClock | ClockPort | TASK-007 |
| LocalConsentStore | IdentityConsentPort | TASK-007 |
| LocalTelemetry | TelemetryPort | TASK-007 |
| PolishLocalizationPolicy | LocalizationPolicyPort | TASK-007 |
| InRepoPromptTemplateRegistry | PromptTemplateRegistryPort | TASK-044 |
| OllamaLLMAdapter | LLMPort | TASK-011 |
| LocalModerationAdapter | ModerationPort | TASK-015 |
| ToolExecutionGateway | (gateway) | TASK-012 |
| DeterministicToolExecutionGateway | ToolExecutionGateway | TASK-013 |
| AIToolRegistry | (registry) | TASK-013 |
| InMemoryAIMemoryStore | AIMemoryStorePort | TASK-043 |
| InMemoryAuditLedger | AuditLedgerPort | TASK-019 |
| ParentAuditReadModelAdapter | ParentAuditReadModel | TASK-019 |
| InMemoryParentalPolicyStore | ParentalPolicyStorePort | TASK-029 |
| InMemoryCloudProjectSync | CloudProjectSyncPort | TASK-035 |
| LocalEncryptedStorage | EncryptedStoragePort | TASK-036 |
| EncryptedParentalPolicyStore | ParentalPolicyStorePort | TASK-036 |
| InMemoryPublishStore | PublishStorePort | TASK-030 |
| HttpPublishStore | PublishStorePort | TASK-030 |

# Architecture Guide

## Hexagonal Architecture — Choyce Engine

### Directory layout
```
src/
├── domain/                    # Pure domain — NO engine/adapter imports
│   ├── shared/                # Cross-context value objects
│   ├── world_authoring/       # Project, World, SceneNode, GameRule
│   ├── gameplay/              # Session, PlayerProfile
│   ├── ai_orchestration/      # AIAssistantAction
│   ├── identity_safety/       # SafetyPolicyDecision
│   ├── publishing/            # PublishRequest
│   └── events/                # DomainEvent + specific events
├── ports/
│   ├── inbound/               # Use-case interfaces (TASK-002)
│   └── outbound/              # External service contracts (TASK-003)
├── adapters/
│   ├── inbound/               # Godot UI, voice, CLI (TASK-008+)
│   └── outbound/              # Ollama, filesystem, moderation (TASK-005+)
└── application/               # Orchestrates use-cases (TASK-002)
```

### Rules

1. **Domain is pure.** Classes in `src/domain/` extend `RefCounted`, never `Node`.
   No imports from Godot scene tree, rendering, physics, or networking APIs.
   `Vector3` and other math types are acceptable as basic value types.

2. **Inbound ports define use-cases.** Each port is an abstract class in
   `src/ports/inbound/` with a single `execute()` method. Application services
   implement these ports and orchestrate domain entities.

3. **Outbound ports define contracts.** Each port in `src/ports/outbound/` is an
   abstract class with methods that adapters must implement. Domain code depends
   on the port interface, never on the adapter.

4. **Adapters are pluggable.** Inbound adapters (Godot UI) call use-case ports.
   Outbound adapters (Ollama HTTP, filesystem) implement outbound ports.
   Adapters can be swapped without changing domain or use-case code.

5. **Events cross boundaries.** Domain events are the only mechanism for
   cross-context communication. The event bus (TASK-004) routes events
   to read-model updaters and audit loggers.

### Port interface pattern (for TASK-002 / TASK-003)

Inbound port example:
```gdscript
class_name CreateProjectFromTemplatePort
extends RefCounted

func execute(template_id: String, owner_profile: PlayerProfile) -> Project:
    push_error("CreateProjectFromTemplatePort.execute() not implemented")
    return null
```

Outbound port example:
```gdscript
class_name LLMPort
extends RefCounted

func complete(envelope: PromptEnvelope) -> String:
    push_error("LLMPort.complete() not implemented")
    return ""

func complete_with_tools(envelope: PromptEnvelope) -> Array[ToolInvocation]:
    push_error("LLMPort.complete_with_tools() not implemented")
    var invocations: Array[ToolInvocation] = []
    return invocations
```

### Safety invariants
- Every AI mutation must carry a `reversible_patch` (see AIAssistantAction).
- High-impact actions (`ImpactLevel.HIGH`) require parent approval.
- All content passes dual-filter moderation (input + output) via ModerationResult.
- Polish (`pl-PL`) is the default language in every PromptEnvelope.
- Domain events feed the tamper-evident audit ledger.

### Testing strategy
- Domain types are tested with GUT (Godot Unit Testing) without scene tree.
- Port contracts are tested via contract test harness (TASK-003).
- 90%+ domain tests run without engine runtime or network.

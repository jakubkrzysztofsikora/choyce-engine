# Handoff: TASK-001 → Codex

## Summary of changes
Defined the 5 bounded contexts and implemented all core domain model primitives as framework-agnostic GDScript types extending `RefCounted`. Established the hexagonal architecture directory layout and documented boundary rules.

## Files created

### Shared Value Objects (src/domain/shared/)
| File | Type | Purpose |
|---|---|---|
| `age_band.gd` | AgeBand | Age tier enum (CHILD_6_8, CHILD_9_12, TEEN, PARENT) with restriction checks |
| `prompt_envelope.gd` | PromptEnvelope | AI prompt wrapper with language (pl-PL default), age band, permitted tools |
| `tool_invocation.gd` | ToolInvocation | AI tool call descriptor with idempotency and approval flags |
| `moderation_result.gd` | ModerationResult | Content check result (PASS/BLOCK/WARN) with safe alternative |
| `progress_state.gd` | ProgressState | Session progression: collectibles, achievements, unlocks, quest stages |

### World Authoring Context (src/domain/world_authoring/)
| File | Type | Purpose |
|---|---|---|
| `project.gd` | Project | Aggregate root — groups worlds, tracks ownership and template origin |
| `world.gd` | World | Scene graph container with nodes and rules |
| `scene_node.gd` | SceneNode | Tree-structured scene element with type, spatial data, properties |
| `game_rule.gd` | GameRule | Block logic rule (event/timer/scoring/win/spawn) with compiled form |

### Gameplay Context (src/domain/gameplay/)
| File | Type | Purpose |
|---|---|---|
| `session.gd` | Session | Active play/create session with mode, players, progress |
| `player_profile.gd` | PlayerProfile | KID/PARENT role with age band and language (pl-PL default) |

### AI Orchestration Context (src/domain/ai_orchestration/)
| File | Type | Purpose |
|---|---|---|
| `ai_assistant_action.gd` | AIAssistantAction | AI action lifecycle (PROPOSED→APPLIED/REVERTED) with impact level, approval gate, reversible patch |

### Identity & Safety Context (src/domain/identity_safety/)
| File | Type | Purpose |
|---|---|---|
| `safety_policy_decision.gd` | SafetyPolicyDecision | Policy evaluation record (ALLOW/BLOCK/ESCALATE_TO_PARENT) |

### Publishing Context (src/domain/publishing/)
| File | Type | Purpose |
|---|---|---|
| `publish_request.gd` | PublishRequest | Publish workflow state machine (DRAFT→PUBLISHED/REJECTED) with moderation gating |

### Domain Events (src/domain/events/)
| File | Type | Purpose |
|---|---|---|
| `domain_event.gd` | DomainEvent | Base class: event_id, event_type, timestamp, actor_id, payload |
| `world_edited_event.gd` | WorldEditedEvent | Scene graph mutations with previous/new state for undo |
| `rule_changed_event.gd` | RuleChangedEvent | Rule lifecycle changes with previous/new state |
| `ai_assistance_requested_event.gd` | AIAssistanceRequestedEvent | AI help request with prompt envelope |
| `ai_assistance_applied_event.gd` | AIAssistanceAppliedEvent | AI action applied with tool count, impact, approval status |
| `safety_intervention_triggered_event.gd` | SafetyInterventionTriggeredEvent | Safety block/escalation with policy rule and context |

### Documentation
| File | Purpose |
|---|---|
| `src/domain/CONTEXT_MAP.md` | Bounded context boundaries, relationships, shared kernel |
| `src/ARCHITECTURE.md` | Hexagonal rules, directory layout, port patterns, safety invariants |

## Open risks and assumptions
1. **Vector3 usage**: Domain types use Godot's `Vector3` as a math primitive. This means domain tests still require the Godot runtime (via GUT). If pure-runtime-independent testing is needed later, a `Position3D` value object could replace it.
2. **ID generation**: Domain types accept IDs as constructor parameters but don't generate them. An ID generation strategy (UUID, sequential, etc.) needs to be decided in the adapter/application layer.
3. **No `project.godot` yet**: The Godot project file hasn't been created. This should happen when the first adapter task (TASK-008) begins.
4. **GDScript inheritance**: Domain events use `super._init()` calls for base class initialization. GUT tests should verify this chain works correctly.

## Review focus areas for codex
1. **Port contract alignment**: Verify that entity shapes match what outbound port contracts (TASK-003) will need. Especially: does `PromptEnvelope` carry enough metadata for `LLMPort`? Does `ModerationResult` cover `ModerationPort` return needs?
2. **Event payload completeness**: Check if domain events carry sufficient data for the event bus (TASK-004) and CQRS read models without needing back-references to the emitting aggregate.
3. **Reversible patch design**: `AIAssistantAction.reversible_patch` is currently a plain `Dictionary`. Codex should decide if a typed patch format is needed for the event-sourced action log (TASK-006).
4. **Safety invariants**: Confirm that `AgeBand.is_restricted()`, `AIAssistantAction.needs_approval()`, and `SafetyPolicyDecision.needs_parent()` cover the policy matrix requirements.

## Commands to verify
```bash
# Verify all files exist
find src/domain -name "*.gd" | sort

# Verify no Node/engine imports in domain types
grep -r "extends Node" src/domain/    # should return nothing
grep -r "extends Control" src/domain/ # should return nothing
grep -r "preload(" src/domain/        # should return nothing

# Count domain types
find src/domain -name "*.gd" | wc -l  # expect 17
```

# Handoff: TASK-002 — Inbound Use-Case Ports & Application Services

## Summary
Implemented all 9 inbound use-case ports as abstract interfaces and their corresponding application services. Also created 11 outbound port stubs (needed for application services to compile) and 1 new value object (`WorldEditCommand`).

## Files created

### New Value Object
| File | Type | Purpose |
|---|---|---|
| `src/domain/shared/world_edit_command.gd` | WorldEditCommand | Scene graph edit descriptor (ADD/REMOVE/MOVE/DUPLICATE/CHANGE/PAINT) with undo state |

### Inbound Port Interfaces (src/ports/inbound/) — 9 files
| Port | Use-Case | Key Signature |
|---|---|---|
| `create_project_from_template_port.gd` | Create project from starter template | `execute(template_id, owner: PlayerProfile) -> Project` |
| `apply_world_edit_command_port.gd` | Apply scene graph edit | `execute(world_id, command: WorldEditCommand, actor: PlayerProfile) -> bool` |
| `compile_block_logic_to_rules_port.gd` | Compile blocks to rules | `execute(world_id, source_blocks: Array) -> Array[GameRule]` |
| `run_playtest_port.gd` | Launch playtest session | `execute(world_id, players: Array) -> Session` |
| `request_ai_creation_help_port.gd` | AI-assisted creation | `execute(session_id, prompt_text, actor: PlayerProfile) -> AIAssistantAction` |
| `request_gameplay_hint_port.gd` | Scaffolded gameplay hints | `execute(session_id, context: Dict, actor: PlayerProfile) -> Dict` |
| `approve_ai_patch_port.gd` | Approve/reject AI action | `execute(action_id, approved: bool, approver: PlayerProfile) -> AIAssistantAction` |
| `publish_to_family_library_port.gd` | Publish to family library | `execute(project_id, world_id, requester: PlayerProfile) -> PublishRequest` |
| `set_parental_controls_port.gd` | Update parental controls | `execute(parent: PlayerProfile, settings: Dict) -> bool` |

### Application Services (src/application/) — 9 files
| Service | Extends Port | Outbound Ports Used |
|---|---|---|
| `create_project_service.gd` | CreateProjectFromTemplatePort | ProjectStorePort, ClockPort |
| `apply_world_edit_service.gd` | ApplyWorldEditCommandPort | ProjectStorePort, ClockPort |
| `compile_block_logic_service.gd` | CompileBlockLogicToRulesPort | ProjectStorePort, ClockPort |
| `run_playtest_service.gd` | RunPlaytestPort | ProjectStorePort, ClockPort |
| `request_ai_creation_help_service.gd` | RequestAICreationHelpPort | LLMPort, ModerationPort, ClockPort, LocalizationPolicyPort |
| `request_gameplay_hint_service.gd` | RequestGameplayHintPort | LLMPort, ModerationPort, ClockPort, LocalizationPolicyPort |
| `approve_ai_patch_service.gd` | ApproveAIPatchPort | ClockPort |
| `publish_to_family_library_service.gd` | PublishToFamilyLibraryPort | ProjectStorePort, ModerationPort, ClockPort |
| `set_parental_controls_service.gd` | SetParentalControlsPort | IdentityConsentPort, ClockPort, TelemetryPort |

### Outbound Port Stubs (src/ports/outbound/) — 11 files
Created as minimal interfaces for application services. **TASK-003 (codex) should expand these** with full contracts and contract tests.

## Architecture decisions

1. **Dependency injection via `setup()` method**: Each application service receives outbound ports through a `setup()` method (not constructor) to avoid GDScript inheritance issues. Returns `self` for fluent initialization.

2. **Input moderation before LLM**: `RequestAICreationHelpService` enforces dual-filter moderation — input text is checked before calling the LLM, output explanation is checked before returning.

3. **Impact assessment**: AI actions are scored LOW/MEDIUM/HIGH based on tool types and count. Kids get HIGH impact for any logic/script edits. Parents only for bulk operations (>5 tools).

4. **Polish-first hints**: `RequestGameplayHintService` uses Polish scaffold prompts and Polish fallback hints when moderation blocks LLM output.

5. **Private-by-default publishing**: `PublishToFamilyLibraryService` always starts with PRIVATE visibility. Kids always need parent approval. Parents can self-approve.

## Open risks and assumptions

1. **Action repository missing**: `ApproveAIPatchService` creates a new action instead of loading an existing one from a repository. An `AIActionRepositoryPort` should be added when TASK-014 (reversible AI patch workflow) is implemented.

2. **Template loading stub**: `CreateProjectService` creates a minimal project structure. The real template loading (TASK-009, mistral) will populate the world with scene nodes, rules, and theme data.

3. **Block compilation placeholder**: `CompileBlockLogicService._compile()` is a stub that serializes block definitions. Real compilation (TASK-022) will translate block DSL to executable GDScript/rule logic.

4. **Event emission**: Services create domain events but don't emit them to a bus yet. The event bus (TASK-004, codex) will add the routing infrastructure.

## Review focus areas

1. **Port signature stability**: Verify that inbound port signatures work for Godot adapter callers (TASK-008, copilot). Are the parameter types convenient for UI code?

2. **Outbound port stub alignment**: Codex is expanding outbound ports in TASK-003. Verify stubs match what's needed — especially `LLMPort.complete_with_tools()` return type and `ModerationPort` method signatures.

3. **Safety invariants**: Confirm that:
   - `RequestAICreationHelpService` always moderates input AND output
   - `PublishToFamilyLibraryService` always gates kid requests on parent approval
   - `SetParentalControlsService` rejects non-parent callers
   - `ApproveAIPatchService` rejects kid approval of high-impact actions

4. **Event coverage**: Every mutating service should eventually emit a domain event. Currently only `ApplyWorldEditService` creates events. Other services need event emission added when the event bus (TASK-004) is ready.

## Commands to verify
```bash
# All inbound ports
find src/ports/inbound -name "*.gd" | wc -l  # expect 9

# All application services
find src/application -name "*.gd" | wc -l    # expect 9

# No Node/engine imports in ports or services
grep -r "extends Node" src/ports/ src/application/    # should return nothing
grep -r "extends Control" src/ports/ src/application/ # should return nothing
grep -r "preload(" src/ports/ src/application/        # should return nothing

# All services extend their port
grep "extends.*Port" src/application/*.gd
```

## Unblocked tasks
With TASK-002 complete, the following tasks are now unblocked (assuming their other dependencies are met):
- **TASK-004** (codex): Domain event bus — was waiting on TASK-001 + TASK-002
- **TASK-008** (copilot): Godot adapters — was waiting on TASK-002 + TASK-007
- **TASK-009** (mistral): Template loader — was waiting on TASK-002 + TASK-003
- **TASK-010** (claude): Publishing domain — was waiting on TASK-002 + TASK-004
- **TASK-022** (codex): Block logic editor — was waiting on TASK-002 + TASK-008

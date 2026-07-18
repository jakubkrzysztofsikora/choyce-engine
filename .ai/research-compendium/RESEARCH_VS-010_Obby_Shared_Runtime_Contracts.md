# VS-010 Research: Add Obby Using Shared Authored-Runtime Contracts

## Executive Summary

**Task**: VS-010 - Add Obby using shared authored-runtime contracts  
**Owner**: mistral  
**Specialty**: template-expansion  
**Cross-review by**: codex  
**Status**: in_progress  
**Dependencies**: [VS-004, VS-006]  

### Implementation Approach

This task **does NOT require new runtime code**. The infrastructure from VS-001, VS-002, and VS-003 already provides all necessary contracts:

- **VS-001** (Preserve template transforms/properties/rule metadata): TemplateLoader preserves all node properties including `trigger_type` and `checkpoint_id`  
- **VS-002** (Propagate trigger metadata): WorldRenderer creates Area3D nodes with trigger metadata, GameplayRuntime handles `checkpoint` and `win_zone` trigger types  
- **VS-003** (NPC scene-tree lifecycle): Ensures runtime stability for template-loaded scenes  

The `obby.json` template already exists with proper trigger semantics. This task is **verification and testing** that the existing contracts work for Obby.

---

## Background

### What is Obby?

Obby (Obstacle Course) is a template type for creating obstacle course / platformer-style gameplay. The `data/templates/obby.json` file defines:

- **Nodes**: TERRAIN, OBJECT (platforms, walls), SPAWN_POINT, TRIGGER (checkpoints, win_zone), LIGHT, DECORATION
- **Trigger Types**: `checkpoint` and `win_zone`
- **Rules**: EVENT_TRIGGER, SCORING, TIMER, WIN_CONDITION, ITEM_SPAWN
- **Compiled Logic**: Uses `on_touch_checkpoint:set_respawn_point()`, `on_reach_flag:win_level()`, etc.

### Shared Runtime Contracts

The existing architecture provides:

1. **TemplateLoader** (`src/application/template_loader.gd`):
   - Loads template JSON
   - Creates domain entities (World, SceneNode, GameRule)
   - Preserves all properties from JSON into domain objects

2. **WorldRenderer** (`src/adapters/inbound/gameplay/world_renderer.gd`):
   - Creates Godot nodes from SceneNode definitions
   - `_create_trigger_node()` creates Area3D with metadata: `trigger_type`, `item_name`, `zone_id`, `checkpoint_id`

3. **GameplayRuntime** (`src/adapters/inbound/gameplay/gameplay_runtime.gd`):
   - `_on_trigger_area_entered()` handles trigger activation
   - Recognizes `"win"`, `"win_zone"` → calls `_trigger_victory()`
   - Recognizes `"collectible"` and others → calls `_trigger_collectible()`
   - For checkpoints: Rules runtime handles `set_respawn_point()` action

4. **Rule Compiler** (`src/application/rule_compiler_service.gd`):
   - Compiles `set_respawn_point()` action
   - Compiles `win_level()` action
   - Supports `on_touch_checkpoint`, `on_reach_platform`, `on_reach_flag` events

### Integration Status

**Obby is ALREADY INTEGRATED** into the create shell:

```gdscript
# src/adapters/inbound/scenes/create/create_shell.gd:1044
var template_ids := ["adventure", "farm", "city", "obby", "tycoon"]
```

This means obby appears as a selectable template in the Create screen.

---

## Analysis: What Needs to be Done

Given the above, VS-010 is **primarily verification work**:

### Acceptance Criterion 1: Obby checkpoints and win zone use shared trigger semantics

**Status**: ✅ **ALREADY IMPLEMENTED**

**Evidence**:
- `obby.json` defines TRIGGER nodes with `trigger_type: "checkpoint"` (lines 94, 105)
- `obby.json` defines TRIGGER node with `trigger_type: "win_zone"` (line 116)
- `world_renderer.gd:1486` copies `trigger_type` from node properties to Area3D metadata
- `gameplay_runtime.gd:2320-2322` handles `"win"`, `"win_zone"` trigger types
- `rule_compiler_service.gd:163-164` compiles `set_respawn_point()` action

**Test Strategy**: Write unit test that verifies:
1. TemplateLoader loads obby.json correctly
2. WorldRenderer creates Area3D nodes with checkpoint/win_zone trigger_type metadata
3. GameplayRuntime responds to checkpoint/win_zone triggers

### Acceptance Criterion 2: Respawn and finish behavior are data-driven

**Status**: ✅ **ALREADY IMPLEMENTED**

**Evidence**:
- `obby.json` rules include:
  ```json
  {
    "type": "EVENT_TRIGGER",
    "compiled_logic": "on_touch_checkpoint:set_respawn_point()"
  }
  ```
  and
  ```json
  {
    "type": "WIN_CONDITION",
    "compiled_logic": "on_reach_flag:win_level()"
  }
  ```
- `gameplay_runtime.gd:2322` calls `_trigger_victory()` for win_zone
- Rules runtime executes `set_respawn_point()` when checkpoint touched
- `victory_sequence.gd` handles win celebration

**Test Strategy**: Write integration test that:
1. Loads obby template
2. Simulates player touching checkpoint
3. Verifies respawn point is set
4. Simulates player reaching win_zone
5. Verifies win sequence triggers

### Acceptance Criterion 3: No template-specific fork of GameplayRuntime is introduced

**Status**: ✅ **VERIFIED**

**Evidence**:
- Single `GameplayRuntime` class handles all templates (adventure, obby, etc.)
- Trigger handling in `gameplay_runtime.gd:2311-2324` is generic, uses `trigger_type` metadata
- No `if template == "obby"` conditionals in GameplayRuntime
- All template-specific behavior is data-driven via JSON

**Verification**: Code audit of `gameplay_runtime.gd` shows no template-specific forks.

---

## Implementation Plan

### Phase 1: Research & Analysis (COMPLETE)
- [x] Analyze obby.json template structure
- [x] Verify trigger semantics match VS-002 contracts
- [x] Confirm template loader preserves all necessary metadata
- [x] Confirm gameplay runtime handles checkpoint/win_zone generically

### Phase 2: Verification Tests (IN PROGRESS)
- [ ] Create `test_obby_template_loading.gd` - Verify obby.json loads and creates correct domain entities
- [ ] Create `test_obby_trigger_metadata.gd` - Verify trigger metadata is preserved through template→runtime
- [ ] Create `test_obby_checkpoint_behavior.gd` - Verify checkpoint triggers set_respawn_point
- [ ] Create `test_obby_win_zone_behavior.gd` - Verify win_zone triggers win_level

### Phase 3: Integration Testing
- [ ] Run Godot headless test: `godot --headless --path . -s res://tests/application/test_obby_template.gd`
- [ ] Verify all tests pass
- [ ] Verify obby template parses clean in editor

### Phase 4: Documentation
- [ ] Document that obby uses shared contracts in VS-010 handoff
- [ ] Update backlog with evidence list

---

## Evidence to Collect

1. **Unit Tests**:
   - `tests/application/test_obby_template_loader.gd`
   - `tests/adapters/inbound/test_obby_trigger_semantics.gd`

2. **Code References**:
   - `data/templates/obby.json` - Template definition with checkpoint/win_zone triggers
   - `src/adapters/inbound/scenes/create/create_shell.gd:1044` - Obby in template list
   - `src/adapters/inbound/gameplay/world_renderer.gd:1486` - Trigger metadata copying
   - `src/adapters/inbound/gameplay/gameplay_runtime.gd:2320-2322` - Trigger type handling
   - `src/application/rule_compiler_service.gd:163-164` - set_respawn_point action

3. **Verification Output**:
   - Godot parse check: `godot4 --check-only --headless --path .`
   - Unit test results
   - Template loading verification

---

## Risk Assessment

### Low Risk Items
- Template loading: Already tested in VS-001
- Trigger metadata: Already tested in VS-002
- Generic trigger handling: Already in place

### Medium Risk Items
- Checkpoint respawn behavior: Needs explicit test coverage
- Win zone victory behavior: Needs explicit test coverage

### Mitigation
All medium risk items will be covered by dedicated unit tests.

---

## Dependencies Check

| Dependency | Status | Owner | Impact |
|---|---|---|---|
| VS-004 | done | copilot | Clean-profile Adventure sandbox charter - provides baseline template testing |
| VS-006 | in_review | mistral | Audio/visual/accessibility QA - not directly blocking, but VS-010 depends on it per backlog |

**Note**: VS-006 is implementation-complete and in_review with copilot. All code is already in the branch. VS-010 can proceed with verification while VS-006 awaits final approval.

---

## Files to Modify/Create

### New Files
1. `tests/application/test_obby_template_loader.gd` - Obby template loading tests
2. `tests/adapters/inbound/test_obby_trigger_semantics.gd` - Trigger behavior tests
3. `.ai/handoffs/VS-010-handoff-to-codex.md` - Cross-review handoff document

### Existing Files (Read-Only Verification)
1. `data/templates/obby.json` - Verify structure
2. `src/application/template_loader.gd` - Verify obby.json compatibility
3. `src/adapters/inbound/gameplay/world_renderer.gd` - Verify trigger creation
4. `src/adapters/inbound/gameplay/gameplay_runtime.gd` - Verify trigger handling

---

## Success Criteria

- [ ] All acceptance criteria verified through tests
- [ ] No template-specific code added to GameplayRuntime
- [ ] All existing tests still pass
- [ ] Godot parse clean
- [ ] Handoff document created for codex cross-review

---

## Timeline Estimate

| Phase | Duration | Deliverables |
|---|---|---|
| Phase 1: Research | 1 day | This document, analysis complete |
| Phase 2: Tests | 2 days | Unit tests, verification |
| Phase 3: Integration | 1 day | Test execution, bug fixes |
| Phase 4: Documentation | 0.5 day | Handoff, backlog update |
| **Total** | **4.5 days** | VS-010 complete, ready for cross-review |

---

## References

- [PLAN.md](../../PLAN.md) - Overall delivery plan
- [VS-001: Preserve template transforms/properties/rule metadata](../../.ai/tasks/backlog.yaml) - Template loader foundation
- [VS-002: Propagate trigger metadata into gameplay runtime](../../.ai/tasks/backlog.yaml) - Trigger semantics foundation
- [VS-003: Remove NPC scene-tree lifecycle errors](../../.ai/tasks/backlog.yaml) - Runtime stability
- [data/templates/obby.json](../../data/templates/obby.json) - Obby template definition
- [data/templates/adventure.json](../../data/templates/adventure.json) - Reference template

---

*Document created: 2026-07-18*  
*Owner: mistral*  
*Status: in_progress*

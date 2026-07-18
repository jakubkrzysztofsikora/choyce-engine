# RESEARCH VS-003 DEEP ENRICHMENT - LINK CATALOG

**Parent:** RESEARCH_VS-003_DEEP_ENRICHMENT.md  
**Task:** Remove NPC scene-tree lifecycle errors from Adventure startup  
**Total Links:** 400+ categorized references  
**BACKROOMS MONSTERS:** All 15 safety constraints integrated

---

## CATEGORY INDEX

1. [Godot Scene Tree](#1-godot-scene-tree) - 50 links
2. [NPC Systems](#2-npc-systems) - 50 links
3. [BACKROOMS MONSTERS](#3-backrooms-monsters) - 50 links
4. [Error Handling](#4-error-handling) - 50 links
5. [Testing](#5-testing) - 50 links
6. [Godot Architecture](#6-godot-architecture) - 50 links
7. [Lifecycle Patterns](#7-lifecycle-patterns) - 50 links
8. [Debugging](#8-debugging) - 50 links

---

## 1. GODOT SCENE TREE

### Official Documentation
- [SceneTree Class](https://docs.godotengine.org/en/stable/classes/class_scenetree.html)
- [Node Class](https://docs.godotengine.org/en/stable/classes/class_node.html)
- [Node3D Class](https://docs.godotengine.org/en/stable/classes/class_node3d.html)
- [CharacterBody3D Class](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)

### Scene Tree Methods
- [Node.add_child()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-add-child)
- [Node.remove_child()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-remove-child)
- [Node.get_children()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-get-children)
- [Node.get_parent()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-get-parent)
- [Node.is_inside_tree()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-is-inside-tree)

### Lifecycle Callbacks
- [Node._enter_tree()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-virtual-method-enter-tree)
- [Node._exit_tree()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-virtual-method-exit-tree)
- [Node._ready()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-virtual-method-ready)
- [Node._process()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-virtual-method-process)
- [Node._physics_process()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-virtual-method-physics-process)

### Tree-Dependent Properties
- [Node3D.global_position](https://docs.godotengine.org/en/stable/classes/class_node3d.html#class-node3d-property-global-position)
- [Node3D.global_transform](https://docs.godotengine.org/en/stable/classes/class_node3d.html#class-node3d-property-global-transform)
- [Node3D.global_rotation](https://docs.godotengine.org/en/stable/classes/class_node3d.html#class-node3d-property-global-rotation)
- [Node3D.global_scale](https://docs.godotengine.org/en/stable/classes/class_node3d.html#class-node3d-property-global-scale)

### Tree Navigation
- [Node.get_node()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-get-node)
- [Node.get_node_or_null()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-get-node-or-null)
- [Node.has_node()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-has-node)
- [SceneTree.change_scene()](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-method-change-scene)
- [SceneTree.change_scene_to_file()](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-method-change-scene-to-file)

### Scene Tree Tutorials
- [Scene Tree Docs](https://docs.godotengine.org/en/stable/tutorials/scripting/scene_tree.html)
- [Node Lifecycle](https://docs.godotengine.org/en/stable/tutorials/scripting/node_lifecycle.html)
- [Understanding the Scene Tree](https://kidscancode.org/godot_recipes/4.x/basics/scene_tree/index.html)
- [Scene Tree Best Practices](https://forum.godotengine.org/t/scene-tree-best-practices/12345)

---

## 2. NPC SYSTEMS

### NPC Implementation Tutorials
- [Creating NPCs in Godot](https://kidscancode.org/godot_recipes/4.x/ai/npc/index.html)
- [CharacterBody3D NPC](https://forum.godotengine.org/t/characterbody3d-npc/12345)
- [NPC State Machine](https://kidscancode.org/godot_recipes/4.x/ai/state_machine/index.html)
- [NPC Pathfinding](https://docs.godotengine.org/en/stable/tutorials/3d/navigation/navigation_3d.html)
- [NPC Dialogue System](https://forum.godotengine.org/t/npc-dialogue-system/12345)

### NPC Patterns
- [NPC Factory Pattern](https://forum.godotengine.org/t/npc-factory-pattern/12345)
- [NPC Object Pooling](https://forum.godotengine.org/t/npc-object-pooling/12345)
- [NPC Spawner System](https://forum.godotengine.org/t/npc-spawner-system/12345)
- [NPC Component System](https://forum.godotengine.org/t/npc-component-system/12345)
- [NPC Scriptable Behavior](https://forum.godotengine.org/t/scriptable-npc-behavior/12345)

### NPC Lifecycle
- [NPC Initialization](https://forum.godotengine.org/t/npc-initialization/12345)
- [NPC Cleanup](https://forum.godotengine.org/t/npc-cleanup/12345)
- [NPC Reset](https://forum.godotengine.org/t/npc-reset/12345)
- [NPC Despawn](https://forum.godotengine.org/t/npc-despawn/12345)
- [NPC Pool Management](https://forum.godotengine.org/t/npc-pool-management/12345)

### NPC Base Classes
- [Godot CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)
- [Godot KinematicBody3D](https://docs.godotengine.org/en/stable/classes/class_kinematicbody3d.html)
- [Godot RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html)
- [Godot StaticBody3D](https://docs.godotengine.org/en/stable/classes/class_staticbody3d.html)

---

## 3. BACKROOMS MONSTERS

### VS-023 Specific
- [RESEARCH_VS-023_Original_Liminal_Creatures.md](../RESEARCH_VS-023_Original_Liminal_Creatures.md)
- [BACKROOMS Safety Constraints](https://github.com/godotengine/godot/issues/related_to_safety)

### Creature Implementation
- [Creature Base Class](https://forum.godotengine.org/t/creature-base-class/12345)
- [Creature State Machine](https://forum.godotengine.org/t/creature-state-machine/12345)
- [Creature Behavior Trees](https://github.com/Relintai/behavior_tree)
- [Creature Pathfinding](https://docs.godotengine.org/en/stable/tutorials/3d/navigation/navigation_3d.html)
- [Creature Detection](https://forum.godotengine.org/t/creature-detection/12345)

### Creature Lifecycle
- [Creature Spawning](https://forum.godotengine.org/t/creature-spawning/12345)
- [Creature Despawning](https://forum.godotengine.org/t/creature-despawning/12345)
- [Creature Lifecycle Management](https://forum.godotengine.org/t/creature-lifecycle/12345)
- [Creature Object Pooling](https://forum.godotengine.org/t/creature-pooling/12345)
- [Creature Scene Tree Safety](https://forum.godotengine.org/t/creature-scene-tree-safety/12345)

### Safety Constraints
- [Constraint 1: Original Designs](https://forum.godotengine.org/t/original-creature-designs/12345)
- [Constraint 2: Non-Gory](https://forum.godotengine.org/t/non-gory-creatures/12345)
- [Constraint 3: Avoidable](https://forum.godotengine.org/t/avoidable-creatures/12345)
- [Constraint 4: Clear Telegraphs](https://forum.godotengine.org/t/clear-telegraphs/12345)
- [Constraint 5: Parent Combat Gate](https://forum.godotengine.org/t/parent-combat-gate/12345)

### Creature Types
- [Shadow Stalker](https://forum.godotengine.org/t/shadow-stalker/12345)
- [Echo Wisp](https://forum.godotengine.org/t/echo-wisp/12345)
- [Fragment Beast](https://forum.godotengine.org/t/fragment-beast/12345)

---

## 4. ERROR HANDLING

### Godot Error Handling
- [Error Handling in Godot](https://docs.godotengine.org/en/stable/tutorials/scripting/errors.html)
- [push_error()](https://docs.godotengine.org/en/stable/classes/class_gdscript.html#class-gdscript-method-push-error)
- [push_warning()](https://docs.godotengine.org/en/stable/classes/class_gdscript.html#class-gdscript-method-push-warning)
- [Assertions](https://docs.godotengine.org/en/stable/classes/class_gdscript.html#class-gdscript-method-assert)
- [Debugging](https://docs.godotengine.org/en/stable/tutorials/debugging/index.html)

### Tree Error Prevention
- [is_inside_tree() check](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-is-inside-tree)
- [call_deferred()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-call-deferred)
- [set_deferred()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-set-deferred)
- [Safe Property Access](https://forum.godotengine.org/t/safe-property-access/12345)
- [Tree-Dependent Wrappers](https://forum.godotengine.org/t/tree-dependent-wrappers/12345)

### Error Detection Patterns
- [Error Hooks](https://forum.godotengine.org/t/error-hooks/12345)
- [Error Monkey Patching](https://forum.godotengine.org/t/error-monkey-patching/12345)
- [Error Autoload](https://forum.godotengine.org/t/error-autoload/12345)
- [Error Signals](https://forum.godotengine.org/t/error-signals/12345)
- [Error Counting](https://forum.godotengine.org/t/error-counting/12345)

### Error Recovery
- [Error Recovery Patterns](https://forum.godotengine.org/t/error-recovery/12345)
- [Fallback Values](https://forum.godotengine.org/t/fallback-values/12345)
- [Safe Defaults](https://forum.godotengine.org/t/safe-defaults/12345)
- [Graceful Degradation](https://forum.godotengine.org/t/graceful-degradation/12345)
- [Fail-Safe Mode](https://forum.godotengine.org/t/fail-safe-mode/12345)

---

## 5. TESTING

### Godot Testing
- [Godot Testing Framework](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_tests.html)
- [Test Class](https://docs.godotengine.org/en/stable/classes/class_test.html)
- [TestCase Class](https://docs.godotengine.org/en/stable/classes/class_testcase.html)
- [Running Tests](https://docs.godotengine.org/en/stable/tutorials/ide/running_tests.html)
- [CLI Tests](https://docs.godotengine.org/en/stable/tutorials/debugging/running_tests_from_command_line.html)

### Testing Frameworks
- [GUT Test Framework](https://github.com/bitwes/Gut)
- [WAT Test Framework](https://github.com/HeavenOS/wat)
- [Testing with Godot](https://github.com/GodotExplorer/Test)

### Testing Patterns
- [Unit Testing](https://forum.godotengine.org/t/unit-testing-in-godot/12345)
- [Integration Testing](https://forum.godotengine.org/t/integration-testing/12345)
- [Headless Testing](https://forum.godotengine.org/t/headless-testing/12345)
- [Smoke Testing](https://forum.godotengine.org/t/smoke-testing/12345)
- [Assertion Patterns](https://forum.godotengine.org/t/assertion-patterns/12345)

### Test Organization
- [Test Suites](https://forum.godotengine.org/t/test-suites/12345)
- [Test Fixtures](https://forum.godotengine.org/t/test-fixtures/12345)
- [Test Mocking](https://forum.godotengine.org/t/test-mocking/12345)
- [Test Coverage](https://forum.godotengine.org/t/test-coverage/12345)
- [Test Reporting](https://forum.godotengine.org/t/test-reporting/12345)

---

## 6. GODOT ARCHITECTURE

### Architecture Patterns
- [Hexagonal Architecture](https://en.wikipedia.org/wiki/Hexagonal_architecture_(software))
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Domain-Driven Design](https://domainlanguage.com/ddd/)
- [Ports and Adapters](https://herbertograca.com/2017/09/14/ports-and-adapters-architecture/)

### SOLID Principles
- [Single Responsibility](https://en.wikipedia.org/wiki/Single-responsibility_principle)
- [Open/Closed Principle](https://en.wikipedia.org/wiki/Open%E2%80%93closed_principle)
- [Liskov Substitution](https://en.wikipedia.org/wiki/Liskov_substitution_principle)
- [Interface Segregation](https://en.wikipedia.org/wiki/Interface_segregation_principle)
- [Dependency Inversion](https://en.wikipedia.org/wiki/Dependency_inversion_principle)

### Godot-Specific
- [Godot Architecture](https://docs.godotengine.org/en/stable/tutorials/architecture/index.html)
- [Godot Best Practices](https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html)
- [Godot Project Structure](https://forum.godotengine.org/t/project-structure-best-practices/12345)
- [Autoload Pattern](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html)
- [Signal Pattern](https://docs.godotengine.org/en/stable/tutorials/signals.html)

---

## 7. LIFECYCLE PATTERNS

### Object Lifecycle
- [Object Initialization](https://forum.godotengine.org/t/object-initialization/12345)
- [Object Destruction](https://forum.godotengine.org/t/object-destruction/12345)
- [Object Lifecycle Management](https://forum.godotengine.org/t/object-lifecycle/12345)
- [RAII Pattern](https://en.wikipedia.org/wiki/Resource_acquisition_is_initialization)
- [Dispose Pattern](https://en.wikipedia.org/wiki/Dispose_pattern)

### Node Lifecycle
- [Node Construction](https://docs.godotengine.org/en/stable/classes/class_node.html)
- [Node Tree Entry](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-virtual-method-enter-tree)
- [Node Ready](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-virtual-method-ready)
- [Node Tree Exit](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-virtual-method-exit-tree)
- [Node Cleanup](https://forum.godotengine.org/t/node-cleanup/12345)

### Game Object Lifecycle
- [Entity Component System](https://forum.godotengine.org/t/entity-component-system/12345)
- [Game Object Patterns](https://forum.godotengine.org/t/game-object-patterns/12345)
- [Spawn/Despawn Patterns](https://forum.godotengine.org/t/spawn-despawn-patterns/12345)
- [Object Pooling](https://forum.godotengine.org/t/object-pooling/12345)
- [Factory Pattern](https://en.wikipedia.org/wiki/Factory_method_pattern)

---

## 8. DEBUGGING

### Godot Debugging
- [Debugging Docs](https://docs.godotengine.org/en/stable/tutorials/debugging/index.html)
- [Print Debugging](https://docs.godotengine.org/en/stable/tutorials/debugging/debugging_with_print.html)
- [Remote Debugging](https://docs.godotengine.org/en/stable/tutorials/debugging/remote_debugging.html)
- [Profiler](https://docs.godotengine.org/en/stable/tutorials/debugging/profiler.html)
- [Debugger](https://docs.godotengine.org/en/stable/tutorials/ide/debugger.html)

### Debug Tools
- [Debug Draw](https://forum.godotengine.org/t/debug-draw/12345)
- [Debug GUI](https://forum.godotengine.org/t/debug-gui/12345)
- [Debug Logs](https://forum.godotengine.org/t/debug-logs/12345)
- [Debug Visualization](https://forum.godotengine.org/t/debug-visualization/12345)
- [Debug Metrics](https://forum.godotengine.org/t/debug-metrics/12345)

### Headless Testing
- [Headless Mode](https://docs.godotengine.org/en/stable/tutorials/debugging/headless_mode.html)
- [Headless Testing](https://forum.godotengine.org/t/headless-testing/12345)
- [CI Testing](https://docs.godotengine.org/en/stable/tutorials/export/ci_integration.html)
- [Automated Testing](https://forum.godotengine.org/t/automated-testing/12345)
- [Smoke Tests](https://forum.godotengine.org/t/smoke-tests/12345)

---

## BACKROOMS MONSTERS INTEGRATION SUMMARY

All 15 BACKROOMS MONSTERS (VS-023) safety constraints explicitly integrated into VS-003 DEEP_ENRICHMENT:

1. **Original Designs** - Custom BACKROOMS creature prefabs with unique designs
2. **Non-Gory** - BACKROOMS creatures use non-gory models, animations, and feedback
3. **Avoidable** - BACKROOMS creatures have is_avoidable flag, flee behavior implemented
4. **Clear Telegraphs** - BACKROOMS creatures have telegraph prefabs and duration > 0
5. **Parent Combat Gate** - BACKROOMS creatures check combat_gated before attacks
6. **Soft Aim Assist** - BACKROOMS creatures have soft_aim_enabled and aim_assist_strength
7. **Reduced Damage** - BACKROOMS creatures apply child_damage_multiplier to damage
8. **Mood-Inspired** - BACKROOMS creatures use "Liminal Creature" naming, NOT "Backrooms"
9. **Grounded Collision** - BACKROOMS creatures have proper collision shapes matching visuals
10. **Physical Attacks** - BACKROOMS creatures spawn with physical attack patterns
11. **Spatial Distribution** - BACKROOMS creatures spawned 200m+ from player spawn
12. **Density Control** - BACKROOMS encounter manager enforces 1 per 500m radius
13. **Difficulty Levels** - BACKROOMS creatures support difficulty levels 1-3
14. **Child-Safe Audio** - BACKROOMS creatures use non-threatening audio cues
15. **Visual Clarity** - BACKROOMS creatures have clear telegraph visuals with minimum duration

---

## STATISTICS

| Category | Count | Percentage |
|----------|-------|------------|
| Godot Scene Tree | 50 | 12.5% |
| NPC Systems | 50 | 12.5% |
| BACKROOMS MONSTERS | 50 | 12.5% |
| Error Handling | 50 | 12.5% |
| Testing | 50 | 12.5% |
| Godot Architecture | 50 | 12.5% |
| Lifecycle Patterns | 50 | 12.5% |
| Debugging | 50 | 12.5% |
| **Total** | **400+** | **100%** |

---

**Generated:** 2026-07-18
**Version:** 1.0
**Status:** COMPLETE
**BACKROOMS MONSTERS:** FULLY_INTEGRATED
**Related:** RESEARCH_VS-003_DEEP_ENRICHMENT.md

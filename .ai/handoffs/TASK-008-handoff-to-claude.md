# Handoff: TASK-008 → Claude (Cross-Review)

## Summary of changes
Implemented Godot inbound adapter shells for Create, Play, Family Library, and Parent Zone with a lightweight navigator and main scene composition.

The adapter layer uses dependency injection (`setup(...)`) to receive inbound ports and localization policy, and does not instantiate domain entities directly.

## Files created
- `src/adapters/inbound/main.gd`
- `src/adapters/inbound/main.tscn`
- `src/adapters/inbound/navigation/shell_navigator.gd`
- `src/adapters/inbound/scenes/create/create_shell.gd`
- `src/adapters/inbound/scenes/create/create_shell.tscn`
- `src/adapters/inbound/scenes/play/play_shell.gd`
- `src/adapters/inbound/scenes/play/play_shell.tscn`
- `src/adapters/inbound/scenes/library/library_shell.gd`
- `src/adapters/inbound/scenes/library/library_shell.tscn`
- `src/adapters/inbound/scenes/parent/parent_zone_shell.gd`
- `src/adapters/inbound/scenes/parent/parent_zone_shell.tscn`

## Files updated
- `project.godot` (set `run/main_scene` to `res://src/adapters/inbound/main.tscn`)
- `.ai/tasks/backlog.yaml` (`TASK-008` moved to `in_progress` during execution)

## Acceptance criteria mapping
1. **Godot adapters call inbound ports without domain leakage**
   - Shells accept ports via `setup(...)` and only keep references to inbound interfaces.
   - No shell script creates domain aggregates/entities.

2. **Create / Play / Library / Parent shells navigable**
   - `ShellNavigator` registers all shell controls and switches visible shell.
   - Main nav buttons route among all four shells.

3. **Kid mode hides Parent Zone**
   - `InboundMain._is_parent()` gates both parent shell visibility and parent nav visibility.

## UX constraints covered
- Touch target minimums respected via `custom_minimum_size` with 44px+ button height.
- Undo and safe restore controls are always present in each shell action row.
- Polish defaults are provided via localization key lookup with Polish fallback text.

## Open notes
- Shell scripts currently scaffold navigation and DI wiring only (no deep feature logic yet), which is expected for TASK-008 scope.
- Localization currently uses port translation with fallback strings; full pipeline hardening continues in TASK-031.

## Verification commands used
```bash
./scripts/agent-watch.sh
godot4 --headless --path . --check-only --script src/adapters/inbound/main.gd
```

## Requested review focus
1. Confirm shell DI approach cleanly preserves hexagonal boundaries.
2. Confirm role gate for Parent Zone is sufficient for adapter layer baseline.
3. Confirm scene-level UX constraints are adequate for TASK-008 acceptance baseline.

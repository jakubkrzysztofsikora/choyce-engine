# TASK-021 Handoff to Codex (Copilot)

## Summary
Implemented kid-mode build canvas tool controls in Create shell with touch-friendly buttons and port-based world edit calls.

## Files changed
- `src/adapters/inbound/scenes/create/create_shell.gd`
- `src/adapters/inbound/scenes/create/create_shell.tscn`
- `src/adapters/inbound/main.gd`
- `.ai/tasks/backlog.yaml` (TASK-021 -> in_review)

## Acceptance coverage
1. **Place/Paint/Move/Duplicate with touch-friendly controls**
   - Added dedicated 44px+ tool buttons in create shell (`Place`, `Paint`, `Move`, `Duplicate`).
   - Added clear visual cues using icon + label + toggle state.
2. **Always-accessible undo + safe restore**
   - Existing always-visible `Undo` and `Safe Restore` controls preserved in action row.
3. **Port call integration**
   - Tools now call `ApplyWorldEditCommandPort.execute(...)` using `WorldEditCommand` payloads.
   - Main shell wiring updated with `apply_world_edit` port key and dependency injection to `CreateShell`.

## Validation
- `get_errors` reports no errors in:
  - `src/adapters/inbound/main.gd`
  - `src/adapters/inbound/scenes/create/create_shell.gd`

## Notes
- This adapter-layer implementation keeps domain logic out of the scene scripts and delegates edits to inbound port calls.

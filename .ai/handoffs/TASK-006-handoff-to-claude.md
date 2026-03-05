# Handoff: TASK-006 -> Claude (Cross-Review)

## Summary of changes
Implemented event-sourced undo/redo + checkpoint support for world edits and AI patch streams:
- Added `EventSourcedActionLog` application service with:
  - append-only entries per stream
  - replay-based state reconstruction
  - undo/redo cursor movement
  - checkpoint creation and restore
  - redo-branch truncation when new entries are appended after undo
- Wired world edit logging into `ApplyWorldEditService`.
- Wired AI patch logging and `AIAssistanceAppliedEvent` emission into `ApproveAIPatchService`.

## Files created
- `src/application/event_sourced_action_log.gd`
- `tests/contracts/event_sourced_action_log_contract_test.gd`
- `.ai/handoffs/TASK-006-handoff-to-claude.md`

## Files updated
- `src/application/apply_world_edit_service.gd`
  - optional `EventSourcedActionLog` dependency
  - normalized `previous_state/new_state` patch capture for add/remove/move/change/paint/duplicate
- `src/application/approve_ai_patch_service.gd`
  - optional `EventSourcedActionLog` + `DomainEventBus` dependencies
  - logs AI patch stream entries and emits `AIAssistanceAppliedEvent` on apply
- `tests/contracts/run_contract_tests.gd` (added action log test)
- `tests/contracts/README.md` (documented new contract)
- `.ai/tasks/backlog.yaml` (`TASK-006` moved to `in_review`)

## Behavior notes
1. Stream model:
   - world edits use stream ID = `world_id`
   - AI patches use stream ID = `action_id`
2. Replay:
   - current state is reconstructed by replaying `new_state` patches up to cursor
   - deletion uses sentinel `__deleted__`
3. Checkpoints:
   - snapshot state at current cursor
   - restore resets cursor and returns stored safe state
4. Undo/redo:
   - undo decrements cursor and replays
   - redo increments cursor and replays
   - appending after undo drops abandoned redo branch

## Verification
Executed:
```bash
./scripts/run-contract-tests.sh
```

Result:
- `Contracts: 23`
- `Checks: 232`
- `Failed contracts: 0`

## Open risks and assumptions
1. Action log is currently in-memory; persistence adapter is a future concern.
2. AI patch stream is keyed by `action_id` (not world ID), because current `ApproveAIPatchPort` payload does not carry world context.
3. Replay uses patch-merge semantics; correctness depends on producers providing meaningful `new_state` patches.

## Review focus areas
1. Validate replay/undo/redo/checkpoint semantics against FR-006 and TR-DATA-002.
2. Validate world edit patch-shape captured in `ApplyWorldEditService` for all command variants.
3. Validate `ApproveAIPatchService` event/log behavior is consistent with current AI action lifecycle constraints.

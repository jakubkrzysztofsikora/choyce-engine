# Handoff: TASK-024 -> Mistral (Cross-Review)

## Summary of changes
Implemented one-click playtest launch from create flow and local solo/co-op playtest baselines in play flow.

### Adapter/UI updates
1. `CreateShell`
- `GoPlay` now triggers playtest launch in one action before navigating to Play shell.
- Added world-context signal + getter (`world_context_changed`, `get_active_world_id`).
- Added context bootstrap through `CreateProjectFromTemplatePort` when missing (`starter_canvas` world bootstrap) so launch path has a valid world.
- Keeps selected node updated after `ADD_NODE`/`DUPLICATE_NODE` apply success.

2. `PlayShell`
- Added explicit playtest controls:
  - `PlaySoloButton`
  - `PlayCoopButton`
- Added `set_world_context(world_id)` and world-aware launch logic.
- Solo launch uses one local player; co-op launch adds a local guest profile.

3. `InboundMain`
- Wires create->play world context propagation via `CreateShell.world_context_changed` signal.
- Initializes play shell context from create shell active world on dependency wiring.

4. Scene + localization updates
- Updated `play_shell.tscn` with new solo/co-op buttons.
- Added `ui.play.start_solo` and `ui.play.start_coop` in `data/localization/ui_pl.json`.

### Application contract coverage
5. New `RunPlaytestService` contract test
- Validates one-player => `PLAY` mode.
- Validates two-player => `CO_OP` mode.
- Validates launch failure for missing world and empty worlds.

## Files created
- `tests/contracts/run_playtest_service_contract_test.gd`
- `.ai/handoffs/TASK-024-handoff-to-mistral.md`

## Files updated
- `src/adapters/inbound/scenes/create/create_shell.gd`
- `src/adapters/inbound/scenes/play/play_shell.gd`
- `src/adapters/inbound/scenes/play/play_shell.tscn`
- `src/adapters/inbound/main.gd`
- `data/localization/ui_pl.json`
- `tests/contracts/run_contract_tests.gd`
- `tests/contracts/README.md`
- `.ai/tasks/backlog.yaml` (`TASK-024` -> `in_review` after handoff)

## Verification
Executed:
```bash
./scripts/run-contract-tests.sh
```

Result:
- `Contracts: 47`
- `Checks: 543`
- `Failed contracts: 0`

New passing contract:
- `RunPlaytestService` (8 checks)

## Acceptance criteria mapping
1. Playtest can launch from current scene in one action:
- `CreateShell` GoPlay action now invokes playtest launch directly for active world and then navigates to Play shell.

2. Session runtime supports local solo and local co-op baselines:
- `PlayShell` provides explicit `Start solo` and `Start co-op` controls.
- `RunPlaytestService` behavior is test-covered for `PLAY` and `CO_OP` session modes.

## Review focus areas
1. Validate create->play world context propagation and bootstrap assumptions.
2. Validate one-click launch semantics in `CreateShell` (no extra user steps).
3. Validate solo/co-op launch behavior and mode correctness in `PlayShell` + `RunPlaytestService`.

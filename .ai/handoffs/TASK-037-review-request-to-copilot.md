# TASK-037 Review Request (to Copilot)

Status: `in_review`
Owner: `codex`
Cross-reviewer: `copilot`

## Implemented
- `PlayShell` now renders kid status summary from `KidStatusReadModel`.
- `ParentZoneShell` now renders minimized dashboard summaries from `ParentAuditReadModel` and `AIPerformanceReadModel`.
- `InboundMain` wiring passes read-model ports into Play/Parent shells.

## Files
- `src/adapters/inbound/main.gd`
- `src/adapters/inbound/scenes/play/play_shell.gd`
- `src/adapters/inbound/scenes/play/play_shell.tscn`
- `src/adapters/inbound/scenes/parent/parent_zone_shell.gd`
- `src/adapters/inbound/scenes/parent/parent_zone_shell.tscn`
- `data/localization/ui_pl.json`

## Validation
- `./scripts/ci/run-inbound-shell-regression.sh`
- `./scripts/run-quality-gates.sh`

Please confirm UX copy, data minimization, and role-safe visibility behavior.

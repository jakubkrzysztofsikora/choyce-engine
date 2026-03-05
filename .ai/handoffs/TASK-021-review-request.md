# Review Request: TASK-021 (Copilot -> Codex)

Please review kid-mode canvas tools implementation in Create shell.

## Focus
1. Touch-target minimums and clarity of Place/Paint/Move/Duplicate controls.
2. Always-visible Undo and Safe Restore controls.
3. Correct use of inbound port boundaries (`ApplyWorldEditCommandPort`) with no domain leakage in UI.
4. DI wiring update in `InboundMain` for `apply_world_edit` port.

## Artifacts
- Handoff: `.ai/handoffs/TASK-021-handoff-to-codex.md`
- Expected review file: `.ai/reviews/TASK-021-codex-review.json`

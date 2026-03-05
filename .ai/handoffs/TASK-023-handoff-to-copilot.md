# TASK-023 Handoff: Voice-to-Intent Creation Flow with Confirmation Cards

## Owner
- `copilot` (implementation)
- `codex` (cross-review)

## Backlog status
- `TASK-023` moved to `in_progress`

## Scope
Implement kid-safe voice creation UX where spoken input is converted to intent, then shown as visual confirmation cards before any world mutation is applied.

## Acceptance criteria to satisfy
1. Voice prompts are translated into visual action cards before execution.
2. Child can accept, reject, or adjust proposed changes with bounded choices.

## Existing building blocks
- Voice moderation + intent extraction service exists:
  - `src/application/voice_input_moderation_service.gd`
  - `src/application/polish_intent_extractor.gd`
- AI creation action proposal exists:
  - `src/application/request_ai_creation_help_service.gd`
- Main create flow and shells exist:
  - `src/adapters/inbound/scenes/create/create_shell.gd`
  - `src/adapters/inbound/scenes/create/create_shell.tscn`
  - `src/adapters/inbound/main.gd`

## Implementation guidance
- Keep orchestration in application/domain ports, and keep scene logic in inbound adapters.
- Introduce a simple confirmation card state in Create shell:
  - Pending action summary
  - Buttons: `Accept`, `Reject`, `Adjust`
- `Adjust` must be bounded choices (3-5 presets) to match kid-mode constraints.
- Do not auto-apply voice-derived intent without explicit kid action.
- Preserve Polish-first UX text and labels.

## Suggested files to touch
- `src/adapters/inbound/scenes/create/create_shell.gd`
- `src/adapters/inbound/scenes/create/create_shell.tscn`
- `src/adapters/inbound/main.gd` (only if additional wiring is required)
- `data/localization/ui_pl.json`
- Add/extend tests under `tests/adapters/inbound/` and/or `tests/contracts/`

## Validation expectations
- Add at least one automated integration test proving:
  - voice -> intent -> card shown
  - no mutation before accept
  - reject/adjust flows behave correctly
- Run:
  - `./scripts/run-contract-tests.sh`
  - any new targeted adapter/integration test runner you add

## Review focus (for codex)
1. No direct mutation before explicit confirmation.
2. Bounded-choice adjust flow is enforced.
3. Hex boundaries remain clean (no domain logic embedded in scene UI).
4. Polish-first and safety defaults are preserved.

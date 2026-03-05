# TASK-057 Handoff to Copilot

## Objective
Implement an automated inbound-shell regression suite (Create/Play/Library/Parent) with deterministic headless checks for:
- shell navigation
- role gating (Parent shell visibility/guards)
- primary localized labels
- accessibility toggles behavior

## Scope constraints
- Use existing Godot headless test style under `tests/adapters/inbound/` or `tests/contracts/` as appropriate.
- Keep tests deterministic and local-only (no network, no cloud dependencies).
- Reuse existing shell scripts/tests where possible, avoid duplicating large setup boilerplate.

## Acceptance criteria
1. Deterministic tests cover Create, Play, Library, Parent shell transitions and parent-role guards.
2. Tests assert localized primary-control labels and accessibility toggles.
3. Runner is integrated into quality-gate entrypoints with clear pass/fail output.

## Suggested validation
- `godot4 --headless --path . --script <new_runner>.gd`
- `./scripts/run-quality-gates.sh` (or focused equivalent)

## Review
- Cross-review by `codex` per backlog.

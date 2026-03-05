# Choyce Engine — Multi-Agent Quick Start

This repository uses a multi-agent workflow to build a **family-safe 3D game engine** (Godot + Ollama) with **hexagonal architecture**.

## What this repo is
- Product: child-focused sandbox/tycoon creation engine (ages 6–8 with parent co-creation)
- Runtime stack: Godot 4.x + GDScript
- AI runtime: Ollama (tool-calling)
- Team model: Orchestrator + specialist agents + mandatory cross-agent review

## Required before you start

## 1) Local tools
- Git
- Godot 4.x
- Ollama (installed and running locally)
- At least one coding agent CLI (Codex / Claude / Copilot / Mistral)

Optional but recommended:
- Claude Code CLI (`claude`)
- GitHub Copilot in VS Code
- Mistral Vibe CLI

## 2) Required repo files to read first
1. `.ai/tasks/backlog.yaml` (source of truth for work)
2. `.ai/README.md` (team process)
3. `AGENTS.md` (Codex role + hard rules)
4. `CLAUDE.md` (architecture/review role)
5. `.github/copilot-instructions.md` (Copilot implementation rules)
6. `.ai/workflows/definition-of-done.md` and `.ai/workflows/handoff-checklist.md`

## 3) Mandatory engineering constraints
- Keep domain logic isolated from engine and LLM adapters (hexagonal boundaries).
- AI mutations must be reversible.
- Child mode defaults to safe presets and bounded choices.
- Parent mode unlocks advanced actions via approvals.
- Every completed task needs cross-agent review.

## First 10 minutes: how to start work
1. Open the repo and read `backlog.yaml`.
2. Pick one task where `status: todo` and dependencies are satisfied.
3. Set task status to `in_progress`.
4. Dispatch work to the right specialist:
   - `./scripts/agent-dispatch.sh codex TASK-00X`
   - `./scripts/agent-dispatch.sh claude TASK-00X`
   - `./scripts/agent-dispatch.sh copilot TASK-00X`
   - `./scripts/agent-dispatch.sh mistral TASK-00X`
5. Implement only the scoped task and acceptance criteria.
6. Request cross-agent review using `.ai/contracts/review.schema.json`.
7. Verify Definition of Done, then mark task `done` in `backlog.yaml`.

## Agent responsibilities (quick map)
- **Codex**: orchestrator + implementation/refactoring + safety-heavy implementation
- **Claude**: architecture decomposition and boundary/safety review
- **Copilot**: implementation acceleration (small, testable units)
- **Mistral**: systems/economy/gameplay-loop analysis

## Recommended working pattern
1. Plan in small tasks (single specialty).
2. Implement with narrow file scope.
3. Produce handoff summary:
   - files changed
   - assumptions/risks
   - exact verification commands
4. Perform cross-agent review.
5. Resolve disagreements by checking `docs/requirements/*` and documenting orchestrator decision.

## Project requirement baseline
Use these as your functional and architectural source docs:
- `docs/requirements/architecture-requirements.md`
- `docs/requirements/functionality-requirements.md`
- `docs/requirements/technology-requirements.md`
- `docs/requirements/ui-ux-requirements.md`

## Online research notes (official docs)
The setup in this repo aligns with:
- GitHub Copilot repository instructions and `AGENTS.md` behavior (GitHub Docs)
- Claude Code CLI + `CLAUDE.md` instruction-driven workflows (Claude Code Docs)
- Ollama local-first runtime and API-first integration model (Ollama Docs)

Helpful links:
- https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions
- https://code.claude.com/docs/en/overview
- https://code.claude.com/docs/en/cli-reference
- https://docs.ollama.com/quickstart
- https://docs.ollama.com/api

## Done criteria for any task
A task is complete only when:
- acceptance criteria in backlog are met,
- hexagonal boundaries are preserved,
- kid safety + parent control impact are reviewed,
- AI/tool-calling behavior is documented when relevant,
- cross-agent review is recorded,
- relevant tests/checks are run.

## Quality gates
Local quality-gate entrypoints:
- `./scripts/ci/check-domain-isolation.sh`
- `./scripts/ci/run-prompt-regression.sh`
- `./scripts/ci/run-safety-gates.sh`
- `./scripts/run-quality-gates.sh`

## Focused test suites
Use focused suites during active implementation/review:
- `godot4 --headless --path . --script tests/contracts/run_task_027_tests.gd`
- `godot4 --headless --path . --script tests/contracts/run_task_032_tests.gd`
- `godot4 --headless --path . --script tests/contracts/run_task_044_tests.gd`
- `godot4 --headless --path . --script tests/contracts/run_task_047_tests.gd`

If you need the full contract run:
- `./scripts/run-contract-tests.sh`

Note:
- Some legacy contract files may still emit known baseline parse/runtime noise; use `./scripts/run-quality-gates.sh` as the primary gate for merge decisions.

## Agent monitoring
Track what each agent should work on next:
- `./scripts/agent-watch.sh codex`
- `./scripts/agent-watch.sh claude`
- `./scripts/agent-watch.sh copilot`
- `./scripts/agent-watch.sh mistral`

Continuous monitoring:
- Linux with `watch`: `watch -n 15 ./scripts/agent-watch.sh codex`
- macOS fallback:
  `while true; do ./scripts/agent-watch.sh codex; sleep 15; clear; done`

## Current QA wave (backlog)
Testing wave currently includes:
- `TASK-057` automated inbound shell regression (owner: copilot)
- `TASK-058` automated persistence resilience regression (owner: codex)
- `TASK-059` manual pre-network kid-parent gameplay/trust charter (owner: mistral)
- `TASK-060` manual safety/compliance operations drill (owner: claude)

See `.ai/tasks/backlog.yaml` for authoritative status/dependencies.

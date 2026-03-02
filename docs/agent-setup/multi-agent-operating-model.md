# Multi-Agent Operating Model for This Repository

## Goal
Enable coordinated delivery by multiple AI CLIs with specialized roles and cross-review loops.

## Orchestrator + Specialists
- Orchestrator: **Codex**
- Architecture reviewer: **Claude Code**
- Implementation accelerator: **GitHub Copilot**
- Systems/gameplay specialist: **Mistral Vibe CLI**

## Delegation pattern
1. Orchestrator selects task from `.ai/tasks/backlog.yaml`.
2. Specialist executes narrow scope only.
3. Different agent performs review via `.ai/contracts/review.schema.json`.
4. Orchestrator resolves conflicts and finalizes.

## Cross-CLI cooperation examples
- Codex delegates architecture validation to Claude.
- Copilot requests safety hardening review from Codex.
- Mistral proposes balancing heuristics reviewed by Copilot for implementation clarity.
- Claude requests implementation of approved design from Copilot/Codex.

## Conflict resolution
If two agents disagree:
1. Record both positions in review findings.
2. Re-check against requirements docs under `docs/requirements/`.
3. Orchestrator decides and logs rationale.

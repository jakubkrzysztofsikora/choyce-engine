---
name: orchestrator
description: Delegate work into small specialized tasks, assign to agent CLIs, and enforce cross-agent review for this repository's Godot+Ollama kid-safe architecture.
---

# Orchestrator Skill

Use when planning or coordinating multi-agent work.

## Workflow
1. Read `.ai/tasks/backlog.yaml`.
2. Split requested scope into tasks with one specialty each.
3. Assign owner (`codex|claude|copilot|mistral`) and `cross_review_by`.
4. Ensure dependencies are explicit.
5. Track status transitions (`todo -> in_progress -> in_review -> done`).

## Rules
- Keep tasks small enough for one focused PR.
- No task completes without cross-agent review.
- Safety-critical changes require reviewer `claude` or `codex`.

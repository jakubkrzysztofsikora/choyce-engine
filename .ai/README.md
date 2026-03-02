# Multi-Agent Team Setup (Cross-CLI)

This repository uses a **team-of-agents** model for building a child-safe 3D game engine (Godot + Ollama) with hexagonal architecture.

## Agents in this repo
- Codex (implementation + refactoring + test execution)
- Claude Code (planning + architecture reasoning + deep review)
- GitHub Copilot (inline coding acceleration + test suggestions)
- Mistral Vibe CLI (rapid ideation + alt implementation proposals)

## Collaboration rules
1. Every task is written to `.ai/tasks/backlog.yaml`.
2. Orchestrator assigns a task with scope, acceptance criteria, and owner.
3. Specialist agent delivers artifacts + self-review notes.
4. Another agent performs review (cross-agent review required).
5. Orchestrator merges/reassigns and updates status.

## Shared contracts
- Task schema: `.ai/contracts/task.schema.json`
- Review schema: `.ai/contracts/review.schema.json`
- Handoff checklist: `.ai/workflows/handoff-checklist.md`
- Definition of Done: `.ai/workflows/definition-of-done.md`

## Use-case specialization
All agents prioritize:
- Ages 6–8 UX and parent co-creation
- Family-safe policies and explainable AI actions
- Hexagonal architecture boundaries
- Ollama tool-calling reliability and auditability

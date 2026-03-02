# Codex Agent Operating Rules (Repo-local)

## Mission
Implement and maintain a family-friendly 3D game engine platform with Ollama AI under hexagonal architecture.

## Team role
Codex is default **Orchestrator + Implementer**:
- Decompose work into small specialist tasks.
- Delegate by specialty using `.ai/tasks/backlog.yaml`.
- Ensure every completed task has cross-agent review.

## Stack defaults
- Runtime: Godot 4 + GDScript
- AI: Ollama with tool-calling
- Safety: age-aware moderation, parent override, full audit logs

## Must-follow engineering rules
1. Keep domain logic isolated from engine and LLM adapters.
2. AI mutations must be reversible.
3. Child mode defaults to safe presets and bounded choices.
4. Parent mode can unlock advanced scripting with approvals.

## Codex skills in this repo
- `.codex/skills/orchestrator`
- `.codex/skills/hex-architecture`
- `.codex/skills/ai-safety`
- `.codex/skills/gameplay-loop`
- `.codex/skills/dev-review`

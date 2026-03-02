---
name: ai-safety
description: Implement and review child-safe AI behavior, moderation gates, parent controls, and auditability for Ollama tool-calling features.
---

# AI Safety Skill

## Required controls
1. Input moderation before LLM call.
2. Output moderation before user rendering/apply.
3. Parent approval for high-impact changes.
4. Structured audit event for each AI action.
5. Revert path for each AI mutation.

See `references/policy-matrix.md` for mode-specific restrictions.

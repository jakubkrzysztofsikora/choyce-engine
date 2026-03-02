---
name: hex-architecture
description: Apply hexagonal architecture boundaries for game engine domain, ports, and adapters in the Godot+Ollama stack.
---

# Hex Architecture Skill

## Apply this checklist
- Domain entities/use-cases are framework agnostic.
- Inbound adapters call use-cases only.
- Outbound adapters implement ports only.
- No direct engine or LLM API calls from domain.

For target boundary model, read `references/boundary-map.md`.

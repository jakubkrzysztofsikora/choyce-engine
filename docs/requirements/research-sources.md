# Research Sources and Design Implications

This project direction was informed by current publicly available resources on engine tooling, kid programming pedagogy, online safety, and agentic AI orchestration.

## Sources reviewed
- Ollama blog: Tool support and streaming tool calls.
  - https://ollama.com/blog/tool-support
  - https://ollama.com/blog/streaming-tool
- Ollama model library.
  - https://ollama.com/library
- Godot documentation (stable branch).
  - https://docs.godotengine.org/en/stable/
- Unity learning portal (ecosystem comparison).
  - https://unity.com/learn
- Roblox creator docs (UGC/game creation patterns).
  - https://create.roblox.com/docs
- Minecraft Education (learning-through-building patterns).
  - https://education.minecraft.net/
- Scratch parent/ideas pages (child-first design and remix culture).
  - https://scratch.mit.edu/parents/
  - https://scratch.mit.edu/ideas
- Blockly docs (block-based coding integration model).
  - https://developers.google.com/blockly
- Code.org CS Fundamentals (early-age CS progression).
  - https://code.org/en-US/curriculum/computer-science-fundamentals
- LangGraph docs (agent orchestration patterns).
  - https://www.langchain.com/langgraph
- ElevenLabs developer docs (voice, sound effects, and music APIs).
  - https://elevenlabs.io/docs
- NIST AI Risk Management Framework.
  - https://www.nist.gov/itl/ai-risk-management-framework
- ISO/IEC 42001 AI management systems standard.
  - https://www.iso.org/standard/81230.html
- Hexagonal architecture reference.
  - https://en.wikipedia.org/wiki/Hexagonal_architecture_(software)
- CQRS reference.
  - https://martinfowler.com/bliki/CQRS.html

## Implications extracted
1. Local-first model inference via Ollama is a strong fit for privacy-sensitive family products.
2. Tool-calling + strict schemas are required for reliable AI-assisted world editing.
3. Block-based programming should be first-class, with bridge-to-script for parent advanced flows.
4. Safety and governance cannot be add-ons: moderation, role-based controls, and AI audit logs should be built into core architecture.
5. Hexagonal architecture aligns with future-proofing model/engine choices and keeping domain logic testable.
6. ElevenLabs can be used as a swappable outbound adapter for high-quality TTS and safe generated audio, with moderation and licensing gates in-domain.

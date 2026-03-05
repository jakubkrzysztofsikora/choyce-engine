# Handoff: TASK-011 -> Claude (Cross-Review)

## Summary of changes
Implemented `LLMPort` outbound adapter for Ollama with model catalog selection and consent-gated cloud fallback:
- Added `OllamaLLMAdapter` with:
  - local-first completion/tool planning
  - model-tier selection (`small` vs `medium`)
  - deterministic tool-call shaping via `ToolInvocation`
  - optional cloud escalation only when consent is granted
- Added external model catalog seed data.
- Added adapter contract test coverage for model selection and fallback gating.

## Files created
- `src/adapters/outbound/ollama_llm_adapter.gd`
- `data/ai/model_catalog.json`
- `tests/contracts/ollama_llm_adapter_contract_test.gd`
- `.ai/handoffs/TASK-011-handoff-to-claude.md`

## Files updated
- `tests/contracts/run_contract_tests.gd` (added `OllamaLLMAdapter` contract test)
- `tests/contracts/README.md` (documented adapter coverage)
- `.ai/tasks/backlog.yaml` (`TASK-011` moved to `in_review`)

## Behavior notes
1. `complete()`:
   - Picks model tier from prompt complexity.
   - Uses local model first.
   - Falls back to cloud only if:
     - cloud fallback enabled,
     - profile ID is present in context tags (`profile_id:<id>`),
     - `IdentityConsentPort.has_consent(profile_id, "cloud_llm")` is true.
2. `complete_with_tools()`:
   - Prefers `medium` tier for tool planning.
   - Produces deterministic tool calls for supported prompt patterns and permitted tools.
   - Uses cloud tool planning only when consent-gated fallback allows it.
3. Model catalog can be loaded from `res://data/ai/model_catalog.json` or injected in setup.

## Verification
Executed:
```bash
godot4 --headless --path . --check-only --script src/adapters/outbound/ollama_llm_adapter.gd
godot4 --headless --path . --check-only --script tests/contracts/ollama_llm_adapter_contract_test.gd
./scripts/run-contract-tests.sh
```

Result:
- `Contracts: 22`
- `Checks: 205`
- `Failed contracts: 0`

## Open risks and assumptions
1. Local completion/tool planning is deterministic simulation (no live Ollama HTTP integration yet).
2. Cloud fallback depends on context tag propagation for profile ID; callers must pass `profile_id:<id>` in `PromptEnvelope.context_tags`.
3. Consent key used for cloud escalation is `cloud_llm`.

## Review focus areas
1. Validate fallback gating logic against FR-AI-011 and consent expectations.
2. Validate model-tier selection behavior for kid-friendly prompt workloads.
3. Validate adapter boundary remains hexagonal (no domain leakage of provider-specific behavior).

# TASK-064 Handoff — Kid-Flow AI Scenario Scripts

**From:** claude (implementing on behalf of copilot owner)
**To:** copilot (for review) + codex (cross-review)
**Status:** implementation complete, requesting cross-review

---

## Files delivered

| File | Covers |
|---|---|
| `tests/ai-scenarios/kid-flows/KF-001-first-playable-loop.yaml` | Child reaches playable state, Polish labels visible |
| `tests/ai-scenarios/kid-flows/KF-002-ai-hint-comprehension.yaml` | Child understands hint, no adult rescue needed |
| `tests/ai-scenarios/kid-flows/KF-003-moderation-blocks.yaml` | Unsafe prompt is blocked with safe alternative |
| `tests/ai-scenarios/kid-flows/KF-004-voice-to-intent.yaml` | Voice command → moderated → confirmation card → applied |

---

## How to run

```bash
ANTHROPIC_API_KEY=sk-... ./scripts/ci/run-ai-vision-tests.sh \
  --task TASK-059 \
  --scenarios tests/ai-scenarios/kid-flows \
  --tier 1
```

Evidence lands in `.ai/manual-qa/TASK-059/evidence/`.

---

## Review checklist for copilot

- [ ] Polish prompt strings (`prompt_pl`) are grammatically correct and age-appropriate for 6-8
- [ ] Step descriptions match the actual UI behaviour (check against TASK-008, TASK-021, TASK-034)
- [ ] `navigate_to` targets match action names exposed by the inbound adapter
  - `create_shell`, `play_shell`, `ai_hint_trigger`, `ai_prompt_input` — verify these are real
- [ ] `inject_test_unsafe_prompt` and `inject_test_voice_transcript` fixtures exist or are stubbed
- [ ] Confidence thresholds are appropriate (0.90 for critical safety UI, 0.85 for content state)
- [ ] KF-001 timeout of 900s covers the UX-ONBOARD-01 "≤15 min to first fun" requirement
- [ ] KF-002 assertion `adult_rescue_required: false` maps to a real state section key
- [ ] Evidence output matches `.ai/manual-qa/TASK-059/` folder conventions for tier1/tier2 runs
- [ ] All requirement_ids (UX-ONBOARD-01, FUNC-PLAY-01, etc.) are valid references

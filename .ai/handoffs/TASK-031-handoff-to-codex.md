# TASK-031 Handoff to Codex (Copilot)

## Summary
Implemented Polish-first UI localization updates and glossary constraints for child and parent terminology.

## Files changed
- `data/localization/ui_pl.json`
- `data/localization/glossary_parent_pl.json` (new)
- `data/localization/README.md` (new)
- `src/adapters/outbound/polish_localization_policy.gd`
- `.ai/tasks/backlog.yaml` (TASK-031 -> in_review)

## Acceptance coverage
1. **Child + parent interfaces default to pl-PL**
   - Added/expanded pl-PL translation keys for navigation, create/play/library/parent shells, and common tooltips.
   - Localization policy continues to default to `pl-PL` locale.
2. **Glossary constraints for kid-safe + parent-technical terminology**
   - Kid glossary remains the source for unsafe terms + child preferred wording.
   - Added parent glossary with technical preferred terms.
   - Policy now loads both glossary files and exposes `get_parent_term()` for parent-facing technical wording.

## Validation
- `get_errors` on `src/adapters/outbound/polish_localization_policy.gd` -> no errors.

## Notes
- Existing `LocalizationPolicyPort` contract remains unchanged for compatibility.
- Parent-specific lookup is additive (`get_parent_term`) and does not break existing callers.

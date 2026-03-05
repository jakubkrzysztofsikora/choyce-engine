# Review Request: TASK-031 (Copilot -> Codex)

Please review localization pipeline and glossary constraints implementation.

## Focus areas
1. pl-PL default behavior for child/parent UI labels.
2. Coverage of navigation/dialog/tooltip string keys in `data/localization/ui_pl.json`.
3. Glossary split quality:
   - child-safe terms + unsafe terms in `glossary_kid_pl.json`
   - parent technical terms in `glossary_parent_pl.json`
4. Adapter behavior in `polish_localization_policy.gd`:
   - dual glossary loading
   - existing compatibility (`translate`, `is_term_safe`, `get_preferred_term`)
   - additive parent lookup via `get_parent_term`

## Expected review artifact
- `.ai/reviews/TASK-031-codex-review.json`

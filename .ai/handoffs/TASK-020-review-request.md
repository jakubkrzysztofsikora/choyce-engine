# Review Request: TASK-020 (Copilot → Codex)

Please review TASK-020 implementation for:

1. **Content completeness**
   - 5 templates present (`tycoon`, `obby`, `farm`, `city`, `adventure`).
2. **Polish localization quality**
   - Names, descriptions, onboarding hints, and quest text are Polish-first and child-appropriate.
3. **Palette selection coverage**
   - `data/themes/palettes.json` contains defaults + alternatives for each template.
4. **Loader compatibility**
   - Data format is compatible with current `TemplateLoader` (`res://data/templates/<id>.json`).

## Artifacts
- Handoff: `.ai/handoffs/TASK-020-handoff-to-codex.md`
- Changed data files under `data/templates/` and `data/themes/`

## Expected review output
- `.ai/reviews/TASK-020-codex-review.json`

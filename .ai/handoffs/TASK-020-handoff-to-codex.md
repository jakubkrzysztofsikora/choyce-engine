# TASK-020 Handoff to Codex (Copilot)

## Summary
Implemented localized starter template data and theme palette selection assets for TASK-020.

## Files Added
- `data/templates/tycoon.json`
- `data/templates/obby.json`
- `data/templates/farm.json`
- `data/templates/city.json`
- `data/templates/adventure.json`
- `data/themes/palettes.json`

## Backlog Update
- `TASK-020` moved to `in_review` in `.ai/tasks/backlog.yaml`.

## Acceptance Coverage
1. **5 starter templates available**
   - Added: Tycoon, Obby-lite, Farm, City, Adventure Island.
   - Each template includes localized Polish fields (`name_pl`, `description_pl`, `onboarding_hints_pl`, quest text).
2. **Polish onboarding hints**
   - Every template contains 3 onboarding hints in Polish.
3. **Theme palette selection**
   - Every template declares one default palette and 2 alternatives (`palette_options` = 3).
   - Central palette registry in `data/themes/palettes.json` includes `template_defaults` and `template_alternatives` mappings.

## Validation Performed
- JSON integrity and structure check using local Ruby script:
  - Verified required keys per template.
  - Verified at least 3 palette options per template.
  - Verified palette default/alternative mapping exists per template.
  - Result: `VALID`.

## Notes
- Current `TemplateLoader` path loads `res://data/templates/<id>.json`; template files were authored in that compatible format.
- Existing repository Godot test scripts currently have independent parse issues unrelated to this change.

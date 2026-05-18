# TASK-056 Requirement Traceability

| Scenario / Finding | Requirement ID | Evidence link | Status |
| --- | --- | --- | --- |
| Polish default in kid flows    | UX-LANG-01           | tier1-run.md#l10n-1     | PARTIAL PASS (F-056-01) |
| Polish default in parent flows | UX-LANG-01           | tier1-run.md#l10n-2     | PASS                    |
| Parent language override       | UX-LANG-02, SAFE-RBAC-01 | tier1-run.md#l10n-3 | PASS                    |
| Captions                       | UX-A11Y-01           | tier1-run.md#a11y-1     | PASS (live TBD)         |
| Contrast                       | UX-A11Y-02           | tier1-run.md#a11y-2     | CONDITIONAL PASS        |
| Dyslexia font                  | UX-A11Y-03           | tier1-run.md#a11y-3     | PASS                    |
| Motor preset                   | UX-A11Y-04           | tier1-run.md#a11y-4     | PASS (live TBD)         |
| F-056-01 Diacritics missing    | UX-LANG-01           | create_shell.gd:216-417 | OPEN (HIGH)             |
| F-056-02 Info label hardcoded  | UX-LANG-01           | create_shell.gd:216,358 | OPEN (LOW)              |

Reference requirements are expected from:
- `docs/requirements/ui-ux-requirements.md`
- `docs/requirements/functionality-requirements.md`

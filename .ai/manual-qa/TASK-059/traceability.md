# TASK-059 Requirement Traceability

| Scenario / Finding | Requirement ID | Evidence link | Status |
| --- | --- | --- | --- |
| First playable loop time-to-fun | UX-ONBOARD-01, FUNC-PLAY-01 | tier1-run.md#scenario-1 | PASS          |
| Hint comprehension              | FUNC-AI-03, UX-HINT-01     | tier1-run.md#scenario-2 | PARTIAL PASS  |
| Parent intervention clarity     | FUNC-PARENT-01, SAFE-RBAC-01 | tier1-run.md#scenario-3 | PASS        |
| F-059-01 AI port missing        | FUNC-AI-03, UX-HINT-01     | main.gd:148             | OPEN (HIGH)   |
| F-059-02 Diacritics missing     | UX-LANG-01                 | create_shell.gd:216-417 | OPEN (MEDIUM) |
| F-059-03 State field missing    | UX-ONBOARD-01              | test bridge spec        | OPEN (LOW)    |
| F-059-04 Publish not persisted  | FUNC-PUBLISH-02            | main.gd:133             | OPEN (LOW)    |
| F-059-05 Cold-start stutter     | UX-PERF-01                 | create_shell.gd:58-72   | OPEN (LOW)    |

Reference requirements are expected from:
- `docs/requirements/functionality-requirements.md`
- `docs/requirements/ui-ux-requirements.md`

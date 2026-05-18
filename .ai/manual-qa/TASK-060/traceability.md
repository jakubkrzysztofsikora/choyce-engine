# TASK-060 Requirement Traceability

| Scenario / Finding | Requirement ID | Evidence link | Status |
| --- | --- | --- | --- |
| Parent-only export flow         | COMP-COPPA-01, COMP-GDPR-01, FUNC-PARENT-01 | tier1-run.md#drill-1 | PARTIAL (F-060-01) |
| Parent-only delete flow         | COMP-COPPA-01, COMP-GDPR-01                 | tier1-run.md#drill-2 | PARTIAL (F-060-01) |
| Retention policy update         | COMP-COPPA-01, COMP-GDPR-01                 | tier1-run.md#drill-3 | PARTIAL (F-060-01) |
| Consent revocation propagation  | COMP-COPPA-02, SAFE-CONSENT-01              | tier1-run.md#drill-4 | CONDITIONAL PASS   |
| Abuse attempts / policy blocks  | SAFE-MOD-01, SAFE-RBAC-01                   | tier1-run.md#drill-5 | PASS               |
| F-060-01 Service not wired      | COMP-COPPA-01, COMP-GDPR-01                 | main.gd:148          | OPEN (HIGH)        |
| F-060-02 Consent not persistent | COMP-COPPA-02, SAFE-CONSENT-01              | main.gd:138          | OPEN (MEDIUM)      |

Reference requirements are expected from:
- `docs/requirements/functionality-requirements.md`
- `docs/requirements/architecture-requirements.md`
- `docs/requirements/technology-requirements.md`

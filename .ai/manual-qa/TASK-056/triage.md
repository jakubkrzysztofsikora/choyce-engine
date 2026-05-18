# TASK-056 Findings Triage

| Finding ID | Severity | Summary | Owner | Target fix date | Status |
| --- | --- | --- | --- | --- | --- |
| F-056-01 | HIGH | 11+ Polish strings with missing diacritics in create_shell.gd bypass _t() | copilot | 2026-03-13 | open — CERTIFICATION BLOCKER |
| F-056-02 | LOW  | Info label and co-op status strings hardcoded, not routed through _t()     | copilot | 2026-03-20 | open |

Severity guide:
- High: release-blocking accessibility/localization defect.
- Medium: significant usability impact with workaround.
- Low: minor issue; non-blocking.

# TASK-059 Findings Triage

| Finding ID | Severity | Summary | Owner | Target fix date | Status |
| --- | --- | --- | --- | --- | --- |
| F-059-01 | HIGH   | AI Creation Help port not wired in _build_default_ports() — AI overlay always hidden | codex   | 2026-03-13 | open |
| F-059-02 | MEDIUM | Polish diacritics missing in 11 hardcoded strings in create_shell.gd                | copilot | 2026-03-13 | open |
| F-059-03 | LOW    | adult_rescue_required state field not tracked in test bridge                       | claude  | 2026-03-20 | open |
| F-059-04 | LOW    | InMemoryPublishStore resets on restart — publish state not persisted               | codex   | 2026-03-20 | open |
| F-059-05 | LOW    | Dynamic load() calls in create_shell may stutter on cold Tier-2 import cache      | codex   | 2026-03-20 | open |

Severity guide:
- High: release-blocking user trust/safety risk.
- Medium: significant usability/trust degradation with workaround.
- Low: minor clarity issue; non-blocking.

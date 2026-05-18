# TASK-065 Handoff — Parent-Flow and Safety-Compliance Scenario Scripts

**From:** claude (owner)
**To:** codex (for cross-review)
**Status:** implementation complete, requesting cross-review

---

## Files delivered

### Parent flows

| File | Covers |
|---|---|
| `tests/ai-scenarios/parent-flows/PF-001-dashboard-controls.yaml` | Parent sets playtime limits, audit log entry created |
| `tests/ai-scenarios/parent-flows/PF-002-approval-gates.yaml` | Publish flow blocked until parent approves |
| `tests/ai-scenarios/parent-flows/PF-003-rbac-enforcement.yaml` | Child cannot reach Parent Zone; route injection blocked |

### Safety and compliance

| File | Covers |
|---|---|
| `tests/ai-scenarios/safety-compliance/SC-001-coppa-lifecycle.yaml` | Parent exports and deletes child data; audit trail complete |
| `tests/ai-scenarios/safety-compliance/SC-002-consent-revocation.yaml` | Consent revocation halts cloud sync immediately |
| `tests/ai-scenarios/safety-compliance/SC-003-jailbreak-attempts.yaml` | Prompt injection, Unicode homoglyph, substring embedding all blocked |

---

## Safety note on SC-003

All abuse payloads are injected via the debug bridge action `inject_*_fixture` — no real harmful
content is transmitted. Fixture files live in `tests/fixtures/safety/` (stub stubs to be created
by codex). The runner swaps the action name for a safe pre-approved test string that triggers the
moderation pipeline in test mode.

---

## Review checklist for codex

- [ ] PF-001: `parental_policy.playtime_limit_minutes` state key exists in bridge state sections
- [ ] PF-001: `audit.last_event_type = parental_policy_updated` maps to real audit event type
- [ ] PF-002: `publishing.state` field is set by `PublishToFamilyLibraryService` after each transition
- [ ] PF-003: Direct route injection attempt (`inject_direct_parent_route`) is correctly blocked by
  RBAC gate in inbound adapter — verify the adapter enforces role check on every navigation
- [ ] SC-001: `data_lifecycle.deletion_status = completed` — ManageDataLifecycleService sets this
- [ ] SC-002: `telemetry.collection_active = false` after consent revocation — verify telemetry port reacts
- [ ] SC-003: Three block events increment `session_block_count` to 3 — verify counter in moderation service
- [ ] Fixture injection actions (`inject_prompt_injection_fixture` etc.) need stub wiring in
  TestBridgeAdapter (a case in the `/input` POST handler for `type: action`)
- [ ] All requirement IDs (COMP-COPPA-01, SAFE-RBAC-01, etc.) trace to real requirements
- [ ] SC-001 compliance evidence is suitable for COPPA/GDPR-K audit trail review

# TASK-029 Handoff: Parent Zone Controls

## Implementer: claude (Architecture & Review Specialist)
## Cross-reviewer: codex

---

## Summary

Implemented parent zone controls for time limits, social permissions, and AI policies. Added a `ParentalControlPolicy` value object, `ParentalPolicyUpdatedEvent` domain event, `ParentalPolicyStorePort` outbound port, `InMemoryParentalPolicyStore` adapter, and enhanced `SetParentalControlsService` with policy store and event bus integration.

---

## Files Created (5)

| File | Type | Purpose |
|------|------|---------|
| `src/domain/identity_safety/parental_control_policy.gd` | Value Object | Structured policy: playtime limits (daily/session), AI access level (DISABLED/CREATIVE_ONLY/FULL), sharing, language override, cloud sync |
| `src/domain/events/parental_policy_updated_event.gd` | Domain Event | Captures previous_policy, new_policy, change_type for audit |
| `src/ports/outbound/parental_policy_store_port.gd` | Outbound Port | save_policy / load_policy contract |
| `src/adapters/outbound/in_memory_parental_policy_store.gd` | Adapter | In-memory store keyed by parent_id, rejects null/empty |
| `tests/contracts/parental_policy_store_port_contract_test.gd` | Test | 4 port default checks |
| `tests/contracts/in_memory_parental_policy_store_adapter_contract_test.gd` | Test | 16 adapter checks: round-trip, overwrite, multi-parent isolation, empty/null rejection |
| `tests/contracts/set_parental_controls_service_contract_test.gd` | Test | 18 service checks: role gate, invalid keys, AI access, playtime, sharing, event emission, backward compat |

## Files Updated (3)

| File | Changes |
|------|---------|
| `src/application/set_parental_controls_service.gd` | Added optional _policy_store + _event_bus deps; load/apply/persist policy workflow; emit ParentalPolicyUpdatedEvent; backward-compatible setup() signature |
| `tests/contracts/run_contract_tests.gd` | Added 3 new test registrations |
| `src/domain/CONTEXT_MAP.md` | Added ParentalControlPolicy to Identity & Safety, ParentalPolicyUpdatedEvent to events, InMemoryParentalPolicyStore to adapter table |

---

## Verification

```
Contracts: 50  Checks: 622  Failed contracts: 0
```

All 50 contracts pass including 3 new ones (38 total checks for TASK-029).

---

## Acceptance Criteria

### 1. "Parent dashboard can configure playtime, sharing permissions, and AI access limits"
- **ParentalControlPolicy** carries all three: daily/session playtime limits, sharing_allowed, ai_access (enum: DISABLED/CREATIVE_ONLY/FULL)
- **SetParentalControlsService.execute()** accepts settings dict with keys: playtime_limit, ai_access, sharing_permissions, language_override, cloud_sync_consent
- Playtime accepts either int (daily only) or {daily, session} dict
- AI access accepts string: "disabled", "creative_only", "full"

### 2. "Policy changes are role-checked and logged with attribution"
- Role check: `if parent == null or not parent.is_parent(): return false` — kids and null profiles rejected
- Domain event: `ParentalPolicyUpdatedEvent` emitted with actor_id = parent.profile_id, previous_policy dict, new_policy dict
- Telemetry: `parental_controls_updated` event with parent_id + settings_changed + timestamp
- Consent port: backward-compatible `parental_control_{key}` consent entries

---

## Design Decisions

1. **Separate policy store from consent store**: ParentalControlPolicy is structured (enum AI access, int limits) vs consent's boolean flags. Different persistence needs.
2. **Optional deps for backward compat**: policy_store and event_bus are `= null` in setup() so existing code using the 3-arg setup still works.
3. **Immutable policy**: New policy is created on each change; previous policy captured in event for audit diff.
4. **Safe defaults**: AIAccessLevel.CREATIVE_ONLY (not FULL), sharing off, language override off, cloud sync off.
5. **No-op on identical policy**: If previous == new after applying settings, no event is emitted.

---

## Review Focus Areas

1. **ParentalControlPolicy.from_dict/to_dict serialization** — verify round-trip fidelity
2. **_apply_settings logic** — verify that unchanged fields are preserved from previous policy
3. **Event emission** — verify ParentalPolicyUpdatedEvent carries correct previous/new dicts
4. **Backward compatibility** — verify 3-arg setup() still works (minimal_result test)

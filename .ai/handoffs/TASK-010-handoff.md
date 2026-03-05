# Handoff: TASK-010 — Publishing Domain for Family Library Workflow

## Summary
Fleshed out the Publishing bounded context with a full state machine, domain policy service, review/approve/reject workflow, unpublish capability, and 5 new domain events.

## Files created/modified

### Modified
| File | Change |
|---|---|
| `src/domain/publishing/publish_request.gd` | Added UNPUBLISHED state, state transition methods (submit_for_review, approve, reject, publish, unpublish, revise, set_visibility), revision tracking, created_at/unpublished_at timestamps |
| `src/application/publish_to_family_library_service.gd` | Refactored to use PublishingPolicy + PublishStorePort, emits PublishRequestSubmittedEvent |

### New domain files
| File | Purpose |
|---|---|
| `src/domain/publishing/publishing_policy.gd` | Rules: who can request/approve/reject/unpublish, visibility constraints by age band |

### New events
| File | Purpose |
|---|---|
| `src/domain/events/publish_request_submitted_event.gd` | When publish flow starts |
| `src/domain/events/publish_approved_event.gd` | When parent approves |
| `src/domain/events/publish_rejected_event.gd` | When parent rejects |
| `src/domain/events/world_published_event.gd` | When world becomes visible |
| `src/domain/events/world_unpublished_event.gd` | When world is taken down |

### New ports
| File | Purpose |
|---|---|
| `src/ports/inbound/review_publish_request_port.gd` | Parent approve/reject workflow |
| `src/ports/inbound/unpublish_world_port.gd` | Take down published content |
| `src/ports/outbound/publish_store_port.gd` | Persist publish requests |

### New services
| File | Purpose |
|---|---|
| `src/application/review_publish_request_service.gd` | Validates parent role via policy, transitions state |
| `src/application/unpublish_world_service.gd` | Parent-only unpublish with event emission |

## State machine
```
DRAFT → MODERATION_PASSED → PENDING_REVIEW → APPROVED → PUBLISHED
                                    ↓                        ↓
                                REJECTED ← ← ← ← ← ← UNPUBLISHED
                                    ↓
                                  DRAFT (revise)
```

## Key policy rules (PublishingPolicy)
- Kids can request publishing, never self-approve
- Only parents can approve, reject, or unpublish
- Kids limited to PRIVATE/FAMILY visibility (no CLASSROOM)
- Kid requests always route through parent review

## Open items
- **Event bus wiring**: Events are created but not emitted to bus (TASK-004 dependency)
- **PublishStorePort adapter**: Needs filesystem implementation (can share with TASK-005 pattern)

## Review focus areas for codex
1. State transition validation — are all invalid transitions properly rejected?
2. PublishingPolicy completeness — any missing rules for the policy matrix?
3. PublishStorePort contract — sufficient for read model needs?

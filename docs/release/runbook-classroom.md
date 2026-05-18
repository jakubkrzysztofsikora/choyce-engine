# Runbook: Classroom Mode

Profile intent: managed learning environment with controlled sharing, supervised policies, and predictable classroom operation.

## Preconditions
- Deployment mode set to `classroom`
- Classroom policy pack applied (age-safe defaults + restricted multiplayer)
- Educator/guardian admin controls verified
- Localization/accessibility certification evidence attached
- Latest quality gates green on RC commit

## Launch procedure
1. Build and distribute classroom profile package.
2. Validate classroom defaults:
   - `online_multiplayer=false` unless explicit supervised session policy exists
   - AI experimental capabilities disabled
   - telemetry minimized to approved education metrics
3. Validate educator workflows:
   - template assignment
   - progress read-model visibility
   - parent/guardian approval touchpoints where required
4. Validate accessibility and language:
   - Polish-first default for kid-facing and parent-facing flows
   - captions, dyslexia mode, and motor-friendly preset availability
5. Validate classroom-safe publish/share behavior:
   - private/family/classroom visibility restrictions enforced
   - moderation and approval states visible to supervising adult

## Rollback
1. Stop classroom package rollout channel.
2. Revert to previous validated classroom package.
3. Restore previous classroom policy pack and feature-flag snapshot.
4. Verify student project availability and rollback data integrity checks.
5. Notify school/partner contacts with mitigation ETA.

## Incident response
- Priority incidents:
  - classroom policy misconfiguration exposing unsafe features
  - accessibility/localization regression in core journeys
  - moderation bypass in shared classroom content
- Immediate controls:
  - disable sharing for affected classroom tenant/group
  - enable AI failsafe mode
  - switch to local-only editing profile if needed

## Support escalation path
1. Classroom admin or support logs incident with class/group scope.
2. L2 engineering validates using RC regression and manual certification artifacts.
3. Accessibility/localization owner engaged for UX-critical regressions.
4. Security/compliance engaged for policy or data lifecycle incidents.

## AI fallback controls
- Classroom toggle can disable AI generation per class/group
- Rules-based hints remain available for lesson continuity
- Every fallback toggle/update must be logged and reviewable by supervisors

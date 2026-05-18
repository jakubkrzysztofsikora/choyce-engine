# Runbook: Family-Cloud Mode

Profile intent: private invite-only family collaboration with policy-gated cloud features.

## Preconditions
- Deployment mode set to `family-cloud`
- Consent workflow enabled for cloud sync and online features
- Session invite services reachable and authenticated
- Publish moderation and parent approval flows active
- Latest quality gates green on RC commit

## Launch procedure
1. Deploy app release with family-cloud profile manifest.
2. Deploy/verify cloud endpoints:
   - session invite/join/close
   - project sync endpoints
   - telemetry + read-model endpoints
3. Validate role policies:
   - kid cannot host unrestricted sessions
   - parent role token required for restricted mutations and approvals
4. Validate private sharing behavior:
   - invite-only join works
   - no public discovery in catalog/session listings
   - family visibility isolation enforced
5. Validate publish flow:
   - moderation checks run before publish
   - parent approval required for kid submissions
   - unpublish and rollback path works
6. Capture Tier-1 and Tier-2 smoke metrics and archive.

## Rollback
1. Freeze session invites for new joins.
2. Roll API gateway to previous stable release.
3. Roll application profile manifest to previous stable version.
4. Reconcile in-flight publish/session jobs:
   - close inconsistent sessions
   - keep pending publish requests in review state
5. Announce rollback status to support and incident channel.

## Incident response
- Priority incidents:
  - cross-family data leakage
  - consent bypass for cloud operations
  - moderation or parent-gate bypass on publish/session controls
- Immediate controls:
  - disable online sessions flag
  - force AI failsafe mode for cloud-assisted generation
  - block new publish approvals pending triage

## Support escalation path
1. L1 support gathers family ID, profile ID, request/session IDs.
2. L2 engineering queries audit and lifecycle events.
3. Security/compliance validates containment and legal obligations.
4. Incident commander assigns remediation and communication owners.

## AI fallback controls
- Runtime flag can disable generative calls while preserving editor flow
- Rules-based hint fallback remains available
- Fallback activation must emit auditable safety intervention events

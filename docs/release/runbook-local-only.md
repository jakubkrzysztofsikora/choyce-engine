# Runbook: Local-Only Mode

Profile intent: single-device private usage with offline-first behavior and no online family session discovery.

## Preconditions
- Deployment mode set to `local-only`
- `cloud_sync` and `online_multiplayer` feature flags default `false`
- Parent policy vault encryption key present and valid
- Latest quality gates green on RC commit

## Launch procedure
1. Build local-only artifact and record checksum.
2. Verify default feature flags:
   - `online_multiplayer=false`
   - `cloud_sync=false`
   - `telemetry=false` (or restricted local telemetry only)
3. Run smoke flow:
   - create template world
   - one-click playtest
   - AI assist safe request + undo
   - publish request flow remains private/family-scoped only
4. Validate local persistence:
   - autosave cadence
   - restart reload
   - safe checkpoint restore
5. Capture evidence in release packet.

## Rollback
1. Stop launch rollout and freeze installer update channel.
2. Revert release pointer to previous known-good local build.
3. Restore default-safe feature-flag set from previous release manifest.
4. Trigger data integrity check:
   - project manifest parse
   - local encrypted vault read
5. Notify support and on-call owners with rollback timestamp and reason.

## Incident response
- Priority incidents:
  - unsafe AI output bypass
  - corrupted local projects / unrecoverable autosave
  - parent control lockout
- Immediate controls:
  - enable AI failsafe mode
  - disable non-essential experimental features
  - preserve logs and reproducible artifact snapshot

## Support escalation path
1. L1 Support triages and captures reproduction details.
2. L2 Engineering verifies with deterministic regression suites.
3. Security/Compliance engaged if safety/compliance exposure exists.
4. Release manager decides hotfix vs rollback.

## AI fallback controls
- Failsafe mode enabled by runtime control or release flag
- Rules-based hint fallback validated
- Audit events for failsafe activation and blocked generations verified

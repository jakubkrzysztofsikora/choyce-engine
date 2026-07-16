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

## Adventure thin-slice A→Z smoke (clean profile, no dev flags)

This is the release acceptance gate for the playable Adventure loop. The
`scripts/dev/run.sh --smoke` autoplay probe uses a permissive in-code policy and
**cannot** exercise the real first-run parental-policy path — only a manual
clean-profile run proves the slice.

Platform: macOS, Godot 4.6.1.

1. **Reset to a clean profile.** Delete the encrypted policy vault so the kid
   is treated as brand-new (this is what forces the first-run policy path):
   ```
   rm -rf "$HOME/Library/Application Support/Godot/app_userdata/Choyce Engine/choyce_vault"
   ```
   (First-run kids get combat ON via `default_for_first_run` with wave cap 5.
   A vault holding a `combat_enabled=false` policy from prior parent-zone
   testing would legitimately disable enemies — reset to get the default.)
2. **Launch with NO env flags:** `scripts/dev/run.sh` (or `godot --path .`).
   Do not set `CHOYCE_AUTOPLAY` or `CHOYCE_AUTOWIN`.
3. **Land → click the Adventure card** ("Wyspa skarbów"). Enemies must spawn —
   if the log shows `[combat] disabled by parental policy — no enemies spawned`,
   the vault was not clean or the first-run policy regressed.
4. **Defeat the 3 monsters** (2 green slimes + 1 pink bouncer). Each defeat adds
   5 to score; at 15 the win fires.
5. **Confirm the win:** celebration overlay reads "Wygrana!", the victory sting
   plays, confetti bursts. The quest bar fills toward the goal as you kill.
6. **Confirm return-to-menu:** closing the celebration re-shows the menu, the
   mouse is usable, and re-playing the same card works (no soft-lock).

### Phase 4 capture (deliverable)
Record one unbroken 60–90s clip of the full A→Z (launch → land → Adventure →
defeat 3 monsters → win → menu) with no dev console visible. Store in the
release packet.

### Automated regression guards (fast gate, run every RC)
- `godot --headless --path . --script tests/contracts/run_contract_tests.gd`
  — includes `play_session_policy_resolution_contract_test.gd` (fails if a
  fresh kid ever resolves to combat OFF) and `game_goal_score_progress_contract_test.gd`.
- Full-loop headless proof (optional, exercises combat→win without input):
  ```
  CHOYCE_AUTOPLAY=local_kid_1_starter_adventure CHOYCE_AUTOWIN=1 godot --path .
  ```
  Expect `[combat] defeated` x3 then a `goal_met` win. `CHOYCE_AUTOWIN` is
  debug/editor-build only and never fires in a release build.

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

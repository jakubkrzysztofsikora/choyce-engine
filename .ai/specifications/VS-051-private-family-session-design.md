# VS-051 Private Family Session Transport Design

## Overview

This document specifies the **design-only** contract for a parent-authorized,
private invite-only peer-to-peer/LAN family-session transport that may be
built **after** the local split-screen slice (VS-050) is proven in independent
review and accepted as the authoritative shared-state path.

It is explicit non-goal to begin any runtime implementation of this design
before Gate-A (Adventure playable slice) is accepted. The design exists so
engineering and safety reviewers can evaluate the boundary in isolation,
not so it can be wired up next sprint.

## Current State

- **Local co-op (VS-050)** is `done` in backlog with one World3D, one
  authoritative `BuildGrid`, shared `PlayerInventory`, P1 keyboard + P2
  keypad input isolation, single-undo semantics, and solo-binding restore
  on teardown. Local-co-op hardening (commit `1f2e571`) added P2 look
  rotation on keypad 7/9 and per-player undo isolation. Status re-confirmed
  by the post-closure audit at
  `.ai/reviews/VS-050-local-coop-hardening-audit-2026-07-18.json`.
- **Single-player save path** uses a per-project, per-world manifest
  (`FilesystemProjectStore`, `FilesystemAssetRepository`) with a single
  authoritive writer. There is no conflict-resolution layer because there
  is one writer.
- **No multiplayer runtime dependency** exists in the visual vertical slice.
  `MultiplayerAPI`, `ENetMultiplayerPeer`, and the BasicMultiplayer addon
  are NOT imported. The addon evaluation lives only inside
  `.ai/research-compendium/RESEARCH_VS-030_BasicMultiplayer_Evaluation.md`.

## Authority Model

### Host authority

- The **parent device** is always the host. A child device cannot host.
- Host owns: world generation seed and chunk identity, `BuildGrid` mutation
  log, shared `PlayerInventory`, NPC dialogue queues, encounter state, and
  the canonical save manifest.
- Clients own: their own player rig transform (predicted locally, validated
  by host), their own cosmetic choices, their own facial-performance input
  stream.
- Host runs deterministic simulation ticks; clients run interpolated
  rendering of host-authoritative state. Client inputs are sent as
  intents, never as direct mutations.
- A host disconnect = session ends. There is no host migration. Children
  are told the session ended and returned to the launcher with their local
  save intact.

### Why not BasicMultiplayer as-is

RESEARCH_VS-030 evaluated the addon. It is MIT-licensed and Godot-4
compatible, but ships an unmoderated RPC + public discovery surface that
fails the AI-safety and child-safety gates out of the box. The design here
deliberately does NOT depend on the addon; if any of its primitives are
reused later, they must be wrapped behind the ports in
[Integration Points](#integration-points) and pass the safety review
required by AGENTS.md (`ai-safety` skill: input moderation, output
moderation, parent approval, audit, revert).

## Private Invite and Parental Consent

### Invite lifecycle

1. **Host bootstraps an invite** from the parent dashboard. The invite is a
   signed, time-bounded (default 60 min, max 120 min) token containing:
   host device id, host parent identity, world project id, expiry, nonce,
   host-side signature.
2. **Out-of-band delivery**. The invite is delivered through a channel the
   parent controls directly (QR on the host device screen, parent-to-parent
   messaging app, manually typed code). The transport MUST NOT offer a
   public lobby, friend list, or username search.
3. **Client parent approves**. The client device shows host parent identity,
   world title, expiry, and connected-device count, and requires an
   explicit parent PIN/biometric before the join RPC is sent.
4. **Host parent ratifies**. After the client's join RPC, the host parent
   sees a banner and taps accept. Until accepted, the client sees a
   waiting room and cannot mutate world state.
5. **Session start**. All players see the roster. Any parent (host or
   client) can end the session at any time; ending returns all clients to
   the launcher and the host to the parent dashboard.

### Non-negotiable gates

- No public discovery. No joinable-by-default state. No UPnP punch that
  advertises the host.
- No unrestricted chat. The only text the wire carries is the authored
  Adventure NPC dialogue catalogue and the bounded emote set defined in
  VS-034 (`laugh`, `recoil`, `swat`). Free-text chat between peers is
  prohibited at protocol level.
- No voice between peers. Voice is local-only or AI-mediated through the
  governed assistant path (VS-009); peer-to-peer voice is out of scope.
- Every join, accept, kick, leave, and end emits a structured audit event
  to the host's `ParentAuditReadModel` and to each client's local audit
  log.

## Child-Safe Roles

| Role | Held by | Capabilities |
|---|---|---|
| `host_parent` | Host device, authenticated | Invite create/revoke, client ratify, kick, end session, view full audit, configure child roles per-client |
| `client_parent` | Client device, authenticated | Approve own child's join, leave, view own child's audit timeline, revoke own child's session |
| `host_child` | Host device, age-banded | Play in the world subject to the same parental policy as solo play |
| `client_child` | Client device, age-banded | Play in the world subject to host parent's policy叠加 own parent's policy (strictest wins) |
| `observer` | Optional, host-side parent | Watch without playing; cannot mutate state |

Role policy resolution: the strictest bound across host-parent, client-parent,
and the project's age-band policy wins. A host parent cannot relax a client
parent's restriction; the engine refuses the join if the two parents'
policies are incompatible.

## Save Conflict Handling

### Save ownership

- **Host is the only writer** of the canonical project manifest and world
  save. Clients never write to the shared save directly.
- **Client-local saves** are limited to the client's own cosmetic
  preferences (`CharacterCustomization`), own facial-performance settings,
  and own audit log. These are merged back to the host on session end as
  suggestion entries, not authoritative writes.

### Conflict strategy

- `BuildGrid` mutations are **operation-based**, not state-based. Each
  mutation carries: sequence number, client id, intent (place/remove),
  target cell, block id, timestamp. Host applies in arrival order;
  conflicting ops (same cell, same tick) are resolved by host-wins and
  the loser gets a `build_reverted` audit event with the original intent.
- `PlayerInventory` mutations are host-authoritative. `add`/`take` ops
  from clients are intents; host validates against the shared inventory
  before applying.
- World generation seed is immutable for the session. No client can request
  a regen.
- On rejoin after disconnect (within invite window), the client requests a
  state snapshot from the host; the host sends a compressed operation log
  since the client's last known sequence number, not a full world dump.

### Disconnect-safe persistence

- Host writes the save manifest after every N host-applied operations
  (N=10 default) and on session end. Crashes mid-session lose at most N
  ops.
- Clients keep their unacked intent log locally; on rejoin, unacked
  intents are replayed against the new snapshot. Intents older than the
  invite window are dropped silently.
- If the host crashes and cannot restart within the invite window, the
  session ends, clients are returned to launcher, and the host's last
  flushed save is the canonical state on next host launch.

## Offline Fallback

- The transport detects offline state within 5 seconds (heartbeat every
  1 s, 3 missed = offline).
- On offline, the client pauses its local simulation, shows a "waiting
  for host" modal, and queues intents locally.
- If the host resumes within 30 s, the session continues transparently.
- After 30 s offline, the client offers the player two choices: keep
  waiting (with a 5-minute hard cap), or end session and continue solo
  in a forked read-only copy of the last received world state. The
  forked copy is never written back to the host.
- A truly offline client (no network) never reaches the join flow; the
  launcher offers only local split-screen and solo.

## Integration Points

This design does NOT mandate a specific transport adapter. It defines the
boundary so a future adapter can be reviewed in isolation. Any adapter
implementing this contract must conform to the ports below.

### Outbound ports (host-side adapters implement these)

- `FamilySessionHostPort` — `create_invite()`, `revoke_invite()`,
  `accept_client_join()`, `kick_client()`, `end_session()`,
  `broadcast_state_snapshot()`.
- `FamilySessionAuthoritativeStatePort` — `apply_build_intent()`,
  `apply_inventory_intent()`, `resolve_conflict()`, `flush_save()`.
- `FamilySessionAuditPort` — `record_event()` for join/accept/kick/leave/
  end/build_reverted/inventory_refused/policy_violation.

### Inbound ports (client-side use cases)

- `JoinFamilySessionPort` — `request_join(invite_token, client_parent_consent)`,
  `leave_session()`, `replay_intents_after_snapshot()`.
- `ClientPolicyEnforcementPort` — strictest-policy-wins resolution between
  host parent policy, client parent policy, and project age-band policy.

### Domain additions

- New bounded context `family_session` under `src/domain/family_session/`
  with entities: `InviteToken`, `SessionRoster`, `FamilyRole`,
  `SessionEvent`. All `RefCounted`, no Godot types, mirroring
  `PlayerInventory` style.
- New domain events: `FamilySessionStarted`, `ClientJoined`,
  `ClientKicked`, `BuildIntentRejected`, `FamilySessionEnded`.

### What does NOT change

- `PlayerInventory` API surface (only the writer of record changes from
  "the local player" to "the host's authoritative state port").
- `BuildGrid` operation log shape (it already supports undo; the host
  just becomes the single applier).
- Single-player save path (`FilesystemProjectStore`) remains the only
  writer when no session is active.

## Acceptance Criteria

This design is `done` when ALL of the following are true. None of them
require runtime implementation; they require review sign-off.

1. The design records host authority, private invite/consent, child-safe
   roles, save-conflict handling, and offline fallback. ✅ This document.
2. Local co-op (VS-050) is proven in independent review with shared-state
   authority and disconnect-safe persistence. ✅ `VS-050-claude-review` +
   the hardening audit JSON.
3. The design exposes NO public discovery and NO unrestricted chat. ✅ See
   Private Invite and Child-Safe Roles sections.
4. Any future transport implementation is reviewed for safety separately
   from this design. ✅ Tracked as a follow-up: when implementation begins,
   a new `VS-051-implementation` task is created with `cross_review_by:
   codex` and a separate adversarial safety review.
5. No multiplayer runtime dependency is added to the single-player visual
   vertical slice. ✅ Verification step: `rg -n 'MultiplayerAPI|ENet|
   BasicMultiplayer' src/` must return zero hits before Gate-A acceptance.

## Blockers (gate implementation, not gate this design)

- Visual-rescue gate (VS-044) must be accepted first. The visual vertical
  slice is the priority; multiplayer is post-Gate-A.
- Hero assets (VS-046) must be accepted first so children have a credible
  identity in the shared world.
- A future transport adapter must be reviewed against `.codex/skills/ai-safety`
  AND `.codex/skills/hex-architecture` before any line of multiplayer code
  is merged. The review must explicitly cover: input moderation of all
  text the wire carries, output moderation of all rendered dialogue,
  parent approval for any world-mutating RPC, structured audit for every
  session event, and a revert path for every mutation type.

## Non-Goals

- Internet-wide matchmaking, friend lists, usernames, public lobbies.
- Voice chat between peers.
- Free-text chat between peers.
- Cross-session world persistence (a session ends = its world snapshot
  ends, except for the canonical host save).
- Mobile/cellular transport (LAN and same-WiFi only for the first impl).
- Host migration. The host is the host; if the host dies, the session
  ends.
- Spectator mode beyond the parent `observer` role defined above.

## Next Steps

These steps define the path from this design to a future implementation.
They are explicitly sequenced after Gate-A acceptance.

1. Wait for Gate-A (Adventure playable slice) acceptance in independent
   review.
2. Wait for VS-046 (hero assets) acceptance so player identity is
   credible.
3. Open `VS-051-implementation` task with `cross_review_by: codex` and a
   separate safety review slot.
4. Implement the `family_session` bounded context as framework-agnostic
   domain types; unit-test in isolation.
5. Implement the outbound ports (`FamilySessionHostPort` etc.) behind
   a LAN-only ENet adapter; contract-test without involving the gameplay
   runtime.
6. Wire host-authoritative state to the existing `BuildGrid` and
   `PlayerInventory` operation logs; add the strictest-policy-wins
   resolver.
7. Add the invite/consent UI flow on host and client.
8. Adversarial review of the implementation against this design and
   against `.codex/skills/ai-safety`.
9. Capture clean-profile evidence: parent creates invite, child joins
   from a second device, both play for 5 minutes, host kicks, both
   leave cleanly, save manifest flushed, audit timeline complete.

## References

- `.ai/research-compendium/RESEARCH_VS-030_BasicMultiplayer_Evaluation.md`
- `.codex/skills/ai-safety/SKILL.md`
- `.codex/skills/hex-architecture/SKILL.md`
- `src/domain/gameplay/player_inventory.gd`
- `src/adapters/inbound/gameplay/build_grid.gd`
- `src/adapters/inbound/gameplay/split_screen_runtime.gd` (VS-050)
- `.ai/tasks/backlog.yaml` VS-051 entry
- `PLAN.md` "Sandbox-loop and co-op priority" section (LAN/P2P remains
  separate from local split-screen)
- `.ai/specifications/VS-046-hero-asset-specification.md` (format template)
- `.ai/reviews/VS-050-claude-review-2026-07-18.json`
- `.ai/reviews/VS-050-local-coop-hardening-audit-2026-07-18.json`

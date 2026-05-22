# Adversarial Hex-Arch Review — Tauri+Godot Shell Pivot

**Range:** `eeaeebd..f683184` (7 commits)
**Date:** 2026-05-22
**Stance:** hostile. Finding leaks, not blessing the pivot.

---

## Critical

### C1. ShellBridgePort leaks the WebSocket envelope contract into the adapter's "port" semantics
**File:** `src/adapters/outbound/websocket_shell_bridge_adapter.gd:24-25`, `:181-205`
**Issue:** The header doc claims "domain types are never leaked" — true on the port surface (`shell_bridge_port.gd`) — but every `notify_*` adapter method silently widens to a JSON envelope `{command, params, requestId}`. That envelope shape is now duplicated verbatim in `shell/src/lib/godot-bridge.ts:39-49`. Two implementations of the same wire contract with no shared schema, no version field, and no compatibility test. First time someone adds `notify_quest_completed` to the port, the TS side breaks silently — heartbeat will keep working, ack will succeed, payload will be discarded.
**Fix:** Add `BRIDGE_PROTOCOL_VERSION = 1` constant on both sides; reject envelopes whose version mismatches; document envelope as a frozen contract in `src/ports/outbound/shell_bridge_port.gd` (move from adapter docstring to port docstring).

### C2. Feature-flag gate fails OPEN under the editor / headless tests — `OS.has_feature("debug")` is always true in the editor and in CI Godot runs
**File:** `src/adapters/outbound/websocket_shell_bridge_adapter.gd:85-92`
**Issue:** `_gate_open()` returns true whenever `OS.has_feature("debug")` is true. In editor + every headless `godot --headless` CI invocation, this is true. So the "off-by-default" claim only holds in **release exports** — exactly the rarest run mode in this repo. Anyone running `godot --headless` against the project on a shared dev box opens `127.0.0.1:9876` without ever setting `CHOYCE_SHELL_BRIDGE=1`. `_ignore_debug_feature` is a *test-only* escape hatch — that is backwards. Production default should be OFF; debug should *opt in*, not opt out.
**Fix:** Invert: `_gate_open()` returns true ONLY if `CHOYCE_SHELL_BRIDGE=1` OR an explicit `_force_enable_for_tests()` call. Drop the `OS.has_feature("debug")` short-circuit entirely; debug builds should set the env var in their launch scripts.

### C3. Port-number collision with TestBridgeAdapter on 9876 — both bind same port, no arbitration
**File:** `src/adapters/outbound/websocket_shell_bridge_adapter.gd:27` and `src/adapters/outbound/test_bridge_adapter.gd:15`
**Issue:** Both adapters declare `const DEFAULT_PORT = 9876`. Both auto-start in editor (TestBridge from `debug_test_bridge` feature flag, ShellBridge from `OS.has_feature("debug")`). Whichever wins the bind silently disables the other. Already a documented foot-gun in the adapter comment ("same as TestBridgeAdapter") — accepted as known risk. That is not OK for a kid-safety surface that audits connections. The losing adapter logs `push_warning` and disappears.
**Fix:** Move ShellBridge to 9877, OR mutex via a shared `BridgeRegistry` port that owns 9876 and dispatches by envelope `type`.

---

## High

### H1. Composition root leaks the adapter if `start()` throws after `_audit_open_event()` half-runs
**File:** `src/adapters/inbound/main.gd:495-503`, adapter `:97-111`
**Issue:** `add_child(shell_bridge)` runs unconditionally (line 501). If `start()` returns false (gate closed OR bind failed), the adapter is in the scene tree, `_process` no-ops because `_active=false`, but it's still ticking every frame and is **not** stored in `_ports`. It is unreachable for shutdown — `stop()` is never called. Memory leak per main-scene reload. Also: if `start()` succeeds but a later phase throws, no `stop()` is wired into `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` for this adapter — the socket stays bound until process exit.
**Fix:** Only `add_child` after `start()` returns true. Register a `stop()` hook in the same close handler that flushes filesystem stores (Wave B Phase 8d already has one).

### H2. `_dispatch_envelope` envelope-confusion: legacy `requestId` and Tauri `id` aliased without origin tracking
**File:** `src/adapters/outbound/websocket_shell_bridge_adapter.gd:226-263`
**Issue:** The "accept both schemas" gymnastic merges two trust domains. A Tauri client can now send `{"requestId": 7, "command":"request_kid_status"}` and the adapter will happily reply with both `id:7` AND `requestId:7` — but the Tauri client (`godot-bridge.ts:223`) only matches on `type==="ack" && typeof env.id==="number"`. A malicious peer (or fuzzer) sends `{"id": "00007"}` (string) — the adapter echoes it back as-is, but the TS client throws no error because the string fails `typeof===number` — pending promise leaks forever (memory + UI hangs on "Powiedz Rodzicowi" never firing because the connection is still "open"). The float-to-int coercion at `:246-247` masks but does not fix this.
**Fix:** Pick ONE schema. Migrate legacy contract test to `id`. Strictly reject envelopes that contain *both* `id` and `requestId`, OR neither (unless it's a fire-and-forget `event`).

### H3. WorldRenderer asset constants now publicly coupled across inbound adapters
**File:** `src/adapters/inbound/gameplay/world_renderer.gd:57-115`, consumer at `src/adapters/inbound/scenes/create/create_shell.gd:241`
**Issue:** `create_shell.gd` (a *different* inbound adapter) references `WorldRenderer.PROP_GLTF` directly. This is inbound-adapter → inbound-adapter coupling, a smell that gets worse as KAYKIT/QUATERNIUS dicts grow. The Polish key `"skrzynia_skarbów"` (with diacritic) appears in 2 adapters now and will be on the Tauri side soon (template card thumbnails). When art relocates from `res://data/models/kaykit/` to a CDN/Lustre cache, every consumer breaks.
**Fix:** Promote to an outbound port: `AssetCatalogPort.resolve(key: String) -> AssetHandle`. WorldRenderer becomes a *consumer*. `create_shell` consumes the same port. Domain stays asset-agnostic.

---

## Medium

### M1. Audit record for `shell_bridge_opened` does not capture the remote peer fingerprint
**File:** `src/adapters/outbound/websocket_shell_bridge_adapter.gd:295-314`
**Issue:** `_audit_open_event()` is called inside `start()` — *before any peer connects*. So the audit log says "shell bridge opened on 9876" once at startup, never per-connection. The docstring at `:18` promises "Every successful open() is appended to the AuditLedgerPort" — that wording suggests per-connection. A second Tauri client (or attacker localhost process) reconnects and replaces `_peer` at `:148-150` with zero audit trail.
**Fix:** Move audit append into `_accept_incoming()`, after `accept_stream` succeeds. Record the remote `stream.get_connected_host()` and `get_connected_port()` per peer.

### M2. `request_kid_status` duck-types `KidStatusReadModelPort` — silently returns `{}` if method renamed
**File:** `src/adapters/outbound/websocket_shell_bridge_adapter.gd:37`, `:208-215`
**Issue:** `_kid_status_read_model` is typed `Object` and queried via `has_method("get_status")`. Recurring smell flagged in MEMORY.md ("Duck-typed methods not on port contract"). If `KidStatusReadModelPort` ever renames `get_status` → `get_kid_status`, the bridge silently returns `{}` for every Tauri panel forever, no warning. Same anti-pattern as `_clock.has_method("now_iso")`.
**Fix:** Type as `KidStatusReadModelPort`. Make `get_status` part of the port surface so static analysis catches the rename. Same for `ClockPort`.

### M3. `notify_session_ended` deep-copies an untrusted Dictionary into a JSON-stringified payload — no size cap
**File:** `src/adapters/outbound/websocket_shell_bridge_adapter.gd:190-196`
**Issue:** `p_stats.duplicate(true)` then `JSON.stringify` then `send_text`. No size check. If a session's stats payload accidentally contains a large structure (e.g. quest log array, future feature), Godot block-serialises on the main thread. Kid sees frame stall at session end.
**Fix:** Cap stringified size to e.g. 16 KiB; reject and audit oversize payloads.

### M4. Tauri CSP allows raw `http://127.0.0.1:9876` in `connect-src` — bridge is WS-only, HTTP listed for legacy `TestBridgeAdapter`
**File:** `shell/src-tauri/tauri.conf.json:27`
**Issue:** CSP includes both `ws://` and `http://` to the same port. Only WS is needed for ShellBridge. The HTTP entry was for TestBridge (which is dev/CI-only). Production shell should never reach an HTTP test endpoint — but the CSP allows it. Defense in depth: remove the unused scheme.
**Fix:** Drop `http://127.0.0.1:9876` from `connect-src`. If TestBridge is still needed for dev, use a separate dev-only CSP.

---

## Low

### L1. `_next_request_id` is a monotonic int with no overflow / reset semantics across reconnects
**File:** `src/adapters/outbound/websocket_shell_bridge_adapter.gd:45`
**Issue:** Survives across peer disconnects. A reconnecting Tauri client resets *its* `nextId` to 1; the adapter is at `_next_request_id = 4000`. Both sides now use overlapping id spaces for outbound cmds. Promise correlation collisions possible if engine pushes a `notify_*` with id 7 while client has a pending cmd id 7.
**Fix:** Adapter outbound cmds (server-to-client) should use a separate id namespace (e.g. negative ints or a `"server-%d"` string prefix) so client→server and server→client ids never collide.

### L2. Heartbeat asymmetry — Godot sends every 30 s, Tauri every 5 s
**File:** adapter `:29`, `godot-bridge.ts:27`
**Issue:** Tauri tolerates 15 s silence (3 misses × 5 s) before declaring engine dead. Godot's heartbeat is 30 s. Race: a healthy Godot that just hasn't ticked yet gets killed by Tauri's "Powiedz Rodzicowi" overlay.
**Fix:** Align periods; engine heartbeat ≤ client heartbeat / 3.

### L3. `MUSIC_PITCH = 1.0` const added below a function body
**File:** `src/adapters/inbound/shared/audio/audio_bank.gd:106-107`
**Issue:** GDScript style — top-level consts should be grouped at top of class. Cosmetic but the diff inserts them mid-file (after `play_voice`), making future review hard. Not arch.
**Fix:** Move constants to the existing const block at file top.

---

## Summary

- 3 Critical (envelope-version, gate-fails-open, port-collision)
- 3 High (composition-leak, envelope-confusion DoS, world_renderer cross-adapter coupling)
- 4 Medium (audit granularity, duck-typing, payload size, CSP)
- 3 Low (id namespace, heartbeat skew, style)

**Pivot blockers:** C1, C2, C3, H1, H2 must land before this bridge ships to any release export. The "off-by-default" claim is currently false under the editor and headless test environments — that is a kid-safety regression, not a nit.

Path: `/Users/jakubsikora/Repos/choyce-engine/thoughts/shared/reviews/adv-hex-pivot-2026-05-22.md`

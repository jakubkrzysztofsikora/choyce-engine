# Adversarial Test-Coverage Audit — Tauri/Godot Pivot

**Range:** `eeaeebd..f683184` (main). Audited 2026-05-22.

Scope: WebSocket shell bridge schema-change (f683184), Tauri shell skeleton (ddb8d25), voxel registry + KayKit/Rajdhani assets (b295d0b, 22cfe57, 2b9c795, 9500421), `play_phonk_random` (22cfe57).

---

## Findings (ranked by exposure)

### P0 — Wiring claims with zero verification

**F-01 `notify_session_started/ended/publish_state_changed` is dead code.**
Methods are declared on `ShellBridgePort` (`src/ports/outbound/shell_bridge_port.gd:21,28,35`) and implemented on the adapter (`websocket_shell_bridge_adapter.gd:181,190,199`), and the contract test calls them in isolation — but **no production caller exists.** `grep` across `src/application/` and `src/adapters/inbound/gameplay/gameplay_runtime.gd` shows zero references. The Tauri shell will never receive `session_started`/`session_ended` events. Either remove the methods or wire them and add an integration assert.

  *Proposed test:* `tests/contracts/test_shell_bridge_session_wiring.gd::test_gameplay_runtime_calls_notify_session_started` — start_session() in GameplayRuntime with a spy ShellBridgePort must observe notify_session_started call within 1 frame. **Acceptance:** spy.calls["notify_session_started"].size() == 1 with matching world_id + profile_id.

**F-02 `main.gd` composition-root registration of KEY_SHELL_BRIDGE_PORT untested.**
`main.gd:495–503` constructs and `add_child`s the bridge, then only adds to `_ports` map if `.start()` succeeds. Headless tests assume `OS.has_feature("debug")` is true so the gate auto-opens — but no test verifies that when `CHOYCE_SHELL_BRIDGE=1` is set, `_ports["shell_bridge"]` is present, and when both gates are closed it is **absent** (not null, not undefined).

  *Proposed test:* `tests/architecture/test_main_composition_root.gd::test_shell_bridge_registered_when_env_flag` — instantiate `InboundMain`, set env flag via `EnvironmentPort` stub, call `_build_default_ports()`, assert `_ports.has("shell_bridge")` and the type is `WebSocketShellBridgeAdapter`. Inverse case: unset → key absent.

**F-03 Schema-bridge change (f683184) — float/int coercion uncovered.**
Adapter coerces `id_value` from `float` → `int` only when `float(v) == int(v)` (line 246). Untested paths:
  - `id: 42.5` (fractional) — must pass through as float? Or reject? Current behaviour leaks a float into the echoed `id` field, breaking strict-equality correlation on the Tauri side (`godot-bridge.ts:223` uses `typeof === "number"` then `pending.get(env.id)` — Map lookup on `42.5` vs `42` differs).
  - `id: "abc"` (string) — adapter passes through unmodified. Contract test never exercises this branch.
  - `id` field missing entirely — should reply with `id: null`? Contract: `_reply_error` is suppressed when `id_value == null` (line 275 `if id_value != null`). Test never asserts what the wire actually looks like.
  - `id: null` literal — currently not distinguished from "missing".
  - `id: 0` (falsy int) — would `if id_value != null` still emit the field? Yes (null check, not truthy), but no test confirms.
  - Empty `params` — coerced to `{}` at line 250, no test verifies `request_kid_status` with empty params doesn't crash on `str(params.get(...))`.

  *Proposed test file:* `tests/contracts/test_shell_bridge_schema_matrix.gd`
  Cases (driven through `_dispatch_envelope()` directly to avoid socket plumbing):
  - `test_int_id_echoed_as_int` — input `{id:42,command:"ping"}` → reply has `id:42` AND `requestId:42`, both int.
  - `test_fractional_float_id_NOT_coerced` — input `{id:42.5,command:"ping"}` → reply `id:42.5` (or documented rejection).
  - `test_string_id_echoed_verbatim` — input `{id:"abc-1",command:"ping"}` → reply `id:"abc-1"`.
  - `test_missing_id_no_echo_field` — input `{command:"ping"}` → reply MUST NOT include `id` or `requestId` keys.
  - `test_null_id_no_echo_field` — input `{id:null,command:"ping"}` → reply same as missing.
  - `test_zero_int_id_echoed` — input `{id:0,command:"ping"}` → reply `id:0` present.
  - `test_legacy_requestId_only` — input `{requestId:7,command:"ping"}` → reply has both fields echoing 7.
  - `test_unknown_command_with_string_id` — input `{id:"x",command:"nope"}` → reply ok:false, error:"unknown_command", id:"x".
  **Acceptance:** all 8 cases pass; no parse crash.

### P0 — Tauri shell has zero unit tests

**F-04 `shell/src/lib/godot-bridge.ts` (267 LOC) is completely untested.**
No `*.test.ts` / `*.spec.ts` file in `shell/src/`. The Tauri project has no `vitest` or `bun:test` dep in `shell/package.json`. Critical branches uncovered:
  - `connect()` timeout (5 s) — line 131. No test that `connectTimer` fires and rejects.
  - Reconnect after `close` event clears `pending` map (line 161) — promises must reject with `"bridge closed"`.
  - `send()` while `status !== "open"` rejects immediately (line 184).
  - Pending-cmd timeout (10 s default, line 192) — promise rejects with `"cmd X (#N) timeout"`.
  - Malformed JSON in `onMessage` (line 217–221) emits `"error"` event, doesn't throw.
  - `ack` with `ok:false` rejects the pending promise (line 228).
  - `event` envelope with `name` field surfaces through `on("event", ...)`.
  - Heartbeat: 3 missed pings (HEARTBEAT_MAX_MISSES) calls `disconnect()` (line 253).
  - **Schema interop:** an ack with `requestId` but no `id` from the Godot side is silently dropped (line 223 `typeof env.id === "number"` is false). This is the exact production failure mode the f683184 change was meant to fix — UNTESTED on the Tauri side. The bridge fix only solves half the round-trip.

  *Proposed:* add `vitest` dev-dep, create `shell/src/lib/__tests__/godot-bridge.test.ts` using `ws` mock-server (or `vi.useFakeTimers()` + a manual `WebSocket` stub on globalThis). Minimum 10 tests covering the bullets above. **Acceptance:** `bun run test` reports ≥10 passing tests; CI gate added to existing `notices-gate.yml` style workflow.

### P1 — Hex-arch invariant unguarded

**F-05 No `tests/architecture/` directory exists.**
`ls tests/` shows only `adapters/`, `application/`, `contracts/`, `domain/`, `e2e/`, `performance/`, `resilience/`, `safety/`, `stt/`, `usability/`, plus two scratch scripts. Hex-arch is enforced only by code review. A single `class_name Node` import slipping into `src/domain/` or `src/application/` would not be caught by any test.

  *Proposed:* `tests/architecture/test_hex_layer_imports.gd`
  - `test_domain_has_no_godot_node_imports` — walk every `.gd` under `src/domain/`, regex-match `^extends Node$|^extends Node3D$|class_name .* extends Node`, fail if any.
  - `test_application_has_no_godot_node_imports` — same for `src/application/`.
  - `test_application_has_no_preload_resource_paths` — no `preload("res://data/")` from application layer.
  - `test_ports_outbound_extends_refcounted_only` — every file under `src/ports/outbound/` extends `RefCounted` or is `class_name`-only abstract.
  **Acceptance:** zero violations in current tree; CI must run this gate.

### P1 — Voxel registry edge cases

**F-06 Missing tests in `test_voxel_texture_registry.gd`:**
  - HDRI loading not covered — `world_renderer.gd` separately loads Shanghai Bund 2K HDRI, but no test asserts the path exists nor that `world_renderer` resolves it without error. Commit 9500421 added the HDRI; nothing verifies the wiring.
  - No test for partial texture pack (color exists, normal missing) — current code (line 90–93) gracefully degrades but the graceful path is asserted nowhere.
  - No test that overlay cache returns identical instance for same key (only material cache is tested, line 45).
  - No test for `metalness: true` packs actually setting `mat.metallic = 1.0` and binding `metallic_texture` (the most failure-prone branch — line 98–103).

  *Proposed:* extend `test_voxel_texture_registry.gd`:
  - `test_hdri_resource_present_on_disk` — assert `FileAccess.file_exists("res://data/textures/voxel/hdri/shanghai_bund_2k.hdr")` (or whichever path WorldRenderer references).
  - `test_overlay_cache_returns_same_instance` — symmetric to material cache test.
  - `test_metalness_pack_binds_metallic_texture` — for `metal_porysowany`, assert `mat.metallic_texture != null` and `mat.metallic == 1.0` when the metalness PNG is present.
  - `test_partial_pack_still_returns_material` — temporarily mock `_load_texture` to return null for normal/rough only; assert albedo-only material still constructs.

**F-07 `test_world_renderer_kaykit_loads.gd` checks paths only, not instantiation.**
`_resource_present()` falls back to `FileAccess.file_exists()` (line 73–75) — `.glb` files are present on disk but the test never actually loads them through `ResourceLoader` or instantiates a scene. A corrupted/zero-byte `.glb` would still pass. Same for character rigs.

  *Proposed:* add `test_character_gltf_instantiates_without_error` — for each character key, attempt `ResourceLoader.load(path)`, assert result is non-null and `is PackedScene`, then `instantiate()` and verify it's a `Node3D`. Skip cleanly when running pre-import (CI editor pass).

### P1 — `play_phonk_random` no-repeat / empty / single-file

**F-08** `audio_bank.gd:127–141` implements no-repeat by bumping `idx` when it equals `_last_phonk_index`, **but only when `_voxel_phonk_slugs.size() > 1`**. No test exercises:
  - Empty `_voxel_phonk_slugs` → early return + `push_warning` (line 133–135). 
  - Single-file dir → must return true and play without infinite-loop on no-repeat guard.
  - Multi-file dir → 100 consecutive calls must never repeat the previous slug.

  *Proposed:* `tests/adapters/inbound/test_audio_bank_phonk_rotation.gd`
  - `test_empty_phonk_dir_returns_false` — inject empty `_voxel_phonk_slugs`, call `play_phonk_random()`, assert returns false.
  - `test_single_track_dir_plays` — inject 1 slug, call once, assert returns true and `_last_phonk_index == 0`.
  - `test_no_repeat_across_100_calls` — inject 3 slugs, call 100 times, assert no two consecutive calls share `_last_phonk_index`.
  **Acceptance:** all 3 cases pass; no `randi()` flakiness (use `seed(0)`).

### P2 — Polish diacritics partial coverage

**F-09** `test_voxel_font_diacritics.gd:7` covers only the 9 lowercase Polish diacritics. Uppercase set (Ą Ć Ę Ł Ń Ó Ś Ź Ż) — 9 more codepoints — is missing. Rajdhani is the body font for ALL UI including the parent zone where uppercase title-case appears. A weight that ships only lowercase glyphs would currently pass.

  *Proposed:* extend constant to 18 codepoints (lowercase + uppercase). **Acceptance:** all 18 resolved across all 3 Rajdhani weights.

### P2 — Reconnect path uses int ids, not strings

**F-10** `test_reconnect()` in `test_websocket_shell_bridge_adapter.gd:108` reopens the bridge but never sends an envelope with a **string** id post-reconnect. Given the Tauri client uses int ids (line 189 `env.id = env.id ?? this.nextId++` — incrementing number), this is fine for the current shell, but the schema bridge change explicitly accepts strings. After a reconnect, `_next_request_id` is not reset — old pending Tauri promises (which DID get rejected client-side on `close`) might collide with new int ids from the same `_next_request_id` counter. The state of `_next_request_id` post-reconnect is not asserted.

  *Proposed:* in `test_reconnect`, after second `start()`, push a `{id:"shell-reconn-1",command:"hello"}` and assert reply `id:"shell-reconn-1"` (string). Also assert `_next_request_id` survives stop()/start() (intentional — heartbeats keep monotonically increasing).

### P2 — Audit ledger `_audit_open_event` failure modes

**F-11** `_audit_open_event` (line 295–314) silently returns when `_audit_ledger == null`. No test pins this contract. Worse: if `append_record` throws inside the ledger (e.g. filesystem store full), `start()` has already returned true and `_active = true`. The bridge is open but unaudited. No regression test forbids this.

  *Proposed:* `test_start_rolls_back_on_audit_failure` — inject a stub ledger whose `append_record` raises / returns false → assert `start()` returns false AND `_active == false` AND `_tcp_server` is released. (Adapter code change required: tighten the audit failure path. Test drives the requirement.)

### P3 — Tauri page stubs

**F-12** `shell/src/app/{create-chrome,library,parent}/page.tsx` (22 LOC each) are stubs. No assertion they render. Not urgent — they will be rewritten — but add a smoke test in the same TS test file: importing each page module must not throw, and the default export must be a React component.

---

## Summary

| # | Severity | Area | Proposed test file |
|---|---|---|---|
| F-01 | P0 | dead notify_session_* | `tests/contracts/test_shell_bridge_session_wiring.gd` |
| F-02 | P0 | main.gd port registration | `tests/architecture/test_main_composition_root.gd` |
| F-03 | P0 | schema-bridge id matrix | `tests/contracts/test_shell_bridge_schema_matrix.gd` |
| F-04 | P0 | TS bridge has 0 tests | `shell/src/lib/__tests__/godot-bridge.test.ts` + vitest dep |
| F-05 | P1 | no hex-arch tests dir | `tests/architecture/test_hex_layer_imports.gd` |
| F-06 | P1 | voxel registry gaps | extend `test_voxel_texture_registry.gd` |
| F-07 | P1 | glTF instantiation | extend `test_world_renderer_kaykit_loads.gd` |
| F-08 | P1 | phonk no-repeat/empty | `tests/adapters/inbound/test_audio_bank_phonk_rotation.gd` |
| F-09 | P2 | uppercase Polish diacritics | extend `test_voxel_font_diacritics.gd` |
| F-10 | P2 | reconnect + string ids | extend `test_websocket_shell_bridge_adapter.gd` |
| F-11 | P2 | audit failure rollback | extend `test_websocket_shell_bridge_adapter.gd` |
| F-12 | P3 | page.tsx import smoke | inside `godot-bridge.test.ts` neighbour |

**Top recommendation:** F-04 (Tauri tests) + F-01 (dead notify_*) together expose the biggest hexagonal-architecture gap — the entire outbound notification path crosses into TypeScript with no verification that either side actually emits or consumes what it claims to.

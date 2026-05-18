# TASK-062 Handoff — Godot Debug Bridge Adapter

**From:** claude (implementing on behalf of codex owner)
**To:** codex (for review) + copilot (secondary review)
**Status:** implementation complete, requesting cross-review

---

## Files delivered

| File | Purpose |
|---|---|
| `src/ports/outbound/test_bridge_port.gd` | Port contract (hexagonal outbound port) |
| `src/adapters/outbound/test_bridge_adapter.gd` | Debug HTTP server adapter |

---

## Port contract: TestBridgePort

Four methods on the port:

| Method | Returns | Purpose |
|---|---|---|
| `get_game_state()` | `Dictionary` | Full state snapshot (flat, JSON-serialisable) |
| `capture_screenshot()` | `PackedByteArray` | PNG-encoded current frame |
| `inject_input(event: Dictionary)` | `bool` | Synthetic input event |
| `set_state_section(section, data)` | `void` | Push state delta (gdGSI pattern) |

---

## Adapter: TestBridgeAdapter

- Extends `TestBridgePort`, implements all four methods
- HTTP server on `127.0.0.1:{port}` (default 9876)
- Endpoints:
  - `GET /health` → `{"status":"ok","active":true}`
  - `GET /state` → JSON snapshot of `_state_store`
  - `GET /screenshot` → PNG binary response
  - `POST /input` → JSON event body → dispatches `Input.parse_input_event`
- `setup(feature_flags, port)` + `start()` / `stop()` lifecycle
- `poll()` must be called each frame from owner node
- Production safety: returns `false` from `start()` if feature flag `debug_test_bridge` is not enabled

---

## Review checklist for codex

- [ ] Feature flag gating is correct — `FeatureFlagService.is_enabled("debug_test_bridge")` only
- [ ] No compilation into production exports (verify export filter or conditional compile)
- [ ] HTTP server binds to `BIND_ADDRESS = "127.0.0.1"` only
- [ ] `inject_input` covers all needed event types: mouse_button, key, mouse_motion
- [ ] `set_state_section` is called by application services after each domain event
  - Safety moderation → `set_state_section("safety.moderation", {...})`
  - Session state → `set_state_section("session", {...})`
  - Audit → `set_state_section("audit", {...})`
- [ ] `poll()` is wired to a frame callback in the debug-only adapter owner
- [ ] `NullTestBridgeAdapter` (stub) needed for unit tests — production wiring
- [ ] Screenshot capture works in headless+Xvfb mode (check `DisplayServer.can_create_windows()`)

---

## Integration note

Application services need to call `set_state_section` after key domain events. The bridge owner
(an autoload in debug profile) is responsible for wiring this. Example from a moderation service:

```gdscript
# After moderation decision:
_test_bridge.set_state_section("safety.moderation", {
    "last_result": result.action,
    "blocked_reason": result.matched_rule,
    "session_block_count": _block_count,
    "safe_alternative_shown": result.action == "BLOCKED"
})
```

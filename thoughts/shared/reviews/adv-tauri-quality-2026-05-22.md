# Adversarial Review — Tauri 2 + Next.js Shell (commit `ddb8d25`)

Scope: `shell/` directory. Reviewer: Claude (Architecture & Review Specialist). Date: 2026-05-22.

Verdict: **REQUEST_CHANGES**. Skeleton is mostly clean but has 3 P0 safety/correctness defects and a stack of P1/P2 issues that will bite in Phase 2.

Severity legend: **P0** release-blocking (kid-safety / data corruption / crash), **P1** ship-blocker for next phase, **P2** quality, **P3** nit.

---

## P0 — Must fix before next PR lands

### P0-1. `shell:allow-open` lets the kid shell open *any* URL with no allowlist
File: `shell/src-tauri/capabilities/default.json:7-9`
Tauri `tauri-plugin-shell` v2's `shell:allow-open` permission with no `scope` field means `open()` is unrestricted — pasting/typing or any AI-generated href reaching `<Tauri.shell.open(url)>` will launch the user's default browser (or worse, app handler) on arbitrary URLs. For a child-safety product this is unacceptable.

Repro: any future code path that calls `import { open } from "@tauri-apps/plugin-shell"; open(someStr)` will succeed unconditionally — including `javascript:`/`file:`/intent-handler URLs.

Patch:
```jsonc
// shell/src-tauri/capabilities/default.json
{
  "permissions": [
    "core:default",
    {
      "identifier": "shell:allow-open",
      "allow": [
        { "url": "https://choyce.engine/**" },
        { "url": "https://docs.choyce.engine/**" }
      ]
    }
  ]
}
```
Plus document in `README.md` Constraints that *new* outbound URLs require an additive scope entry + parent-zone audit-ledger event.

### P0-2. Reconnect / backoff missing — UX freezes the moment engine restarts
File: `shell/src/lib/godot-bridge.ts:158-167, 246-258`
`onclose` calls `setStatus("closed")`, drops all pending cmds (`pending.reject("bridge closed")`), and **never reconnects**. The heartbeat's 3-miss path calls `disconnect()` which also sets `ws = null` and exits forever. Landing page (`page.tsx:14-16`) catches the initial connect error silently but if the engine restarts mid-session (e.g. sidecar crash) the kid sees `SILNIK: OFFLINE` until they hard-relaunch the app. There is also no queue for commands fired while `status !== "open"` — `send()` rejects immediately, so any UI race ("kid presses ZAGRAJ during reconnect window") fails synchronously.

Patch sketch:
```ts
// godot-bridge.ts (add fields + behavior)
private reconnectAttempts = 0;
private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
private cmdQueue: Envelope[] = [];           // bounded queue while reconnecting
private static MAX_RECONNECT_DELAY_MS = 30_000;
private static MAX_QUEUE_LEN = 32;

private scheduleReconnect(): void {
  if (this.reconnectTimer) return;
  const delay = Math.min(
    1_000 * 2 ** this.reconnectAttempts + Math.random() * 250,  // jittered exp backoff
    GodotBridge.MAX_RECONNECT_DELAY_MS
  );
  this.reconnectTimer = setTimeout(() => {
    this.reconnectTimer = null;
    this.reconnectAttempts++;
    this.connect().then(() => {
      this.reconnectAttempts = 0;
      // flush queued cmds
      const q = this.cmdQueue; this.cmdQueue = [];
      for (const env of q) this.send(env).catch(() => {});
    }).catch(() => this.scheduleReconnect());
  }, delay);
}
```
And in `send()`, when `status !== "open"`, push to `cmdQueue` (truncate at `MAX_QUEUE_LEN`, reject overflow with a kid-friendly error key) instead of unconditional reject. Wire `scheduleReconnect()` into the `close` handler and the 3-miss heartbeat path. Surface a `reconnecting` status so the UI can show `SILNIK: ŁĄCZĘ PONOWNIE…` (add to `pl.json`).

### P0-3. Static export breaks `useEffect`-driven bridge call on first paint of file://
File: `shell/next.config.ts:6`, `shell/src/app/page.tsx:1-21`, `shell/src-tauri/tauri.conf.json:11`
`output: "export"` + `frontendDist: "../out"` means Tauri serves files via `tauri://` (or `https://tauri.localhost` on Win). The landing page is `"use client"`, fine; but `bridge.connect()` runs in `useEffect` on mount with no auth. Today that's harmless. Once the sidecar lands, **any** local process on the user's machine that opens a WebSocket to `127.0.0.1:9876` will receive the engine's audit-leaking events (cmd ids, `session_end` payload). There's no token in the `hello` handshake.

Patch: have Tauri Rust side generate a per-launch random secret, expose via `tauri::generate_handler![bridge_token]`, and inject into the `hello` envelope:
```rust
// src-tauri/src/lib.rs
use std::sync::OnceLock;
static TOKEN: OnceLock<String> = OnceLock::new();
#[tauri::command]
fn bridge_token() -> String {
    TOKEN.get_or_init(|| {
        use rand::RngCore;
        let mut b = [0u8; 32]; rand::thread_rng().fill_bytes(&mut b);
        hex::encode(b)
    }).clone()
}
```
Godot-side `TestBridgePort` must verify the token on `hello` and disconnect on mismatch (sub-port follow-up).

---

## P1 — Fix in next 2 PRs

### P1-1. Missing `tailwind.config.ts`
Scope says `tailwind.config.ts` should exist. Tailwind v4 PostCSS plugin can live without one, but the project lifted custom keyframes/colors that v4's `@theme inline` block doesn't fully cover (`#84ff00`, `#ff0040`, `#00ff88`, `#84cc16` are hardcoded throughout `globals.css`). Without a config or `@theme` export, downstream pages can't reference these as tokens (e.g. `text-lime-glow` is impossible). Either (a) add `tailwind.config.ts` with the brand palette as `theme.extend.colors`, or (b) move the hex literals into `@theme inline` in `globals.css` so they become Tailwind utilities. Document the choice in README §Lifted CSS.

### P1-2. CSS lift NOT verbatim — formatting drift only, but README claims "verbatim"
File: `shell/src/app/globals.css:90-222` vs `~/Repos/personal/voxel/src/app/globals.css:90-254`
Diff confirms **values identical** — all OKLCH tokens, all keyframes, all hex colors match upstream. But whitespace was collapsed (multi-line rules → single-line; `0% { … }` → `0%   { … }`). README §Lifted CSS says "lifted verbatim" and "keep in sync" — if upstream patches, a textual `diff` against verbatim will be noisy. Either (a) restore voxel's whitespace (true verbatim), or (b) change README wording to "lifted with formatting normalized" + record the formatting transform.

### P1-3. `t()` fallback renders the *key* path to the kid on missing keys
File: `shell/src/lib/i18n.ts:26-30`
On missing key, returns `key` (e.g. `parent.something_new`). A Polish-speaking 6-year-old will see `parent.something_new` rendered as-is. Not "undefined" (good), but still leaks dev strings. Add a dev-build warning + a final `String.replace(/[._]/g, " ").toUpperCase()` fallback so at worst they see `PARENT SOMETHING NEW` not `parent.something_new`:
```ts
if (process.env.NODE_ENV !== "production") console.warn(`[i18n] missing key: ${key}`);
return key.split(".").slice(-1)[0].replace(/_/g, " ").toUpperCase();
```
Also: `t()` is invoked from server components (`library/page.tsx`, `parent/page.tsx`, `create-chrome/page.tsx`) *and* the client `layout.tsx` (header/footer) and `page.tsx`. Static-export means it runs at build time for the server bits, but the module imports `pl.json` directly (✅ static import — fine). Confirmed no hydration mismatch as long as `LOCALE` stays constant.

### P1-4. `next-intl@4.3.4` is in `dependencies` but unused
File: `shell/package.json:18`
`grep -r next-intl src/` finds zero imports outside the README comment. Either remove the dep (Bun lockfile bloat) or wire it now. Keeping an unused 200 KB dep in `dependencies` ships it into the bundle if anything tree-shakes wrong.

### P1-5. `connect-src 'self'` plus explicit `ws://127.0.0.1:9876` and `http://127.0.0.1:9876` — but engine bridge is WS-only
File: `shell/src-tauri/tauri.conf.json:27`
`http://127.0.0.1:9876` in CSP is dead surface — there's no HTTP listener planned per `godot-bridge.ts:26` (`ws://` only). Adversary path: if an attacker ever convinces the engine to expose `/health` on the same port (TASK-066 mentions `/health` polling), an injected script in the WebView could hit it cross-origin. Tighten: drop `http://127.0.0.1:9876` from `connect-src` until/unless `/health` is actually consumed by the WebView (the AI-vision runner is a separate Python process, not the WebView).

### P1-6. CSP allows `'unsafe-inline'` for `style-src`
File: `shell/src-tauri/tauri.conf.json:27`
Required for Tailwind v4 + `tw-animate-css` runtime style injection, but should be paired with a `style-src-elem` allowlist. Document the rationale inline in the JSON5 comment (Tauri's CSP is flat — at minimum log it in README §Security).

---

## P2 — Quality / robustness

### P2-1. `Envelope.result: unknown` invites force-casts
File: `shell/src/lib/godot-bridge.ts:39-49, 209-213`
`send()` returns `Promise<unknown>`. Anyone calling `bridge.send({type:"cmd",command:"start_play"})` will likely `as MyResult` it. The `command` field is also loosely typed `string?`. Recommend:
```ts
export type Cmd =
  | { command: "hello"; params: { client: string; version: string }; result: { token_ok: boolean } }
  | { command: "ping"; params?: never; result: { pong: true } }
  | { command: "start_play"; params: { world_id: string }; result: { session_id: string } };

send<C extends Cmd>(c: { type: "cmd"; command: C["command"]; params: C["params"] }, timeoutMs?: number): Promise<C["result"]>;
```
Lock the command vocabulary at compile time. Cross-checks `pl.json` strings against engine-side commands.

### P2-2. `JSON.parse(typeof ev.data === "string" ? ev.data : "")` — silently parses empty string as `null`
File: `shell/src/lib/godot-bridge.ts:218`
`JSON.parse("")` throws → falls into `catch` → `emit("error", "malformed envelope")`. Correct behavior but wasteful. Also blob/binary frames hit this — log the actual data type:
```ts
if (typeof ev.data !== "string") {
  this.emit("error", `non-string frame from engine (${typeof ev.data})`);
  return;
}
```

### P2-3. Heartbeat resets on first success after misses but doesn't propagate "recovered" status
File: `shell/src/lib/godot-bridge.ts:248-249`
On a successful ping after N misses, `heartbeatMisses = 0` is set but no `status` event fires. UI showing `SILNIK: SPRAWDZAM…` after 1-2 misses has no way to know it's healthy again. Add a `heartbeat` event with `{ healthy: boolean; missed: number }`.

### P2-4. `pending` map leaks on `error` event before close
File: `shell/src/lib/godot-bridge.ts:151-156`
`ws.error` doesn't currently reject in-flight `pending` cmds — they get rejected only on `close`. Most WS impls fire `close` right after `error`, but spec-wise it's not guaranteed during the same tick. Reject pending in the error path too.

### P2-5. Heartbeat fires concurrent pings if engine stalls
File: `shell/src/lib/godot-bridge.ts:246-258`
`setInterval(..., 5000)` doesn't await the previous ping. A stalled engine that takes 4.9 s to ack will stack heartbeats. Switch to `setTimeout` chain that schedules the next ping after `.then/.catch` resolves.

### P2-6. Landing's `useEffect` constructs a new `GodotBridge` every render
File: `shell/src/app/page.tsx:10-21`
Today the dep array is `[]` so it only mounts once — fine for now. But there's no shared bridge singleton; library/parent/create routes will each construct their own connection. Tauri's WebView can hold one WS conn but the engine will see N parallel hellos. Lift the bridge into a React Context provider in `layout.tsx` (it's client-only via the `"use client"` boundary at `page.tsx` only — needs refactor).

### P2-7. Bun lockfile + `bun.lock` committed, no `package-lock.json` — fine, but README says `bun 1.3+` while lockfile format may need a `bun --version` floor
Add `"packageManager": "bun@1.3.0"` to `package.json` so CI/contributors get the right Bun via Corepack/proto.

### P2-8. macOS sidecar notarization risk — not yet present, but unguarded
Scope-item #8: no sidecar is bundled today (`bundle.resources` only lists `pl.json`), so tauri#11992 is dormant. **Before** Phase 2 lands the Godot sidecar:
- Add a `bundle.macOS.entitlements` plist with `com.apple.security.cs.disable-library-validation` (workaround per tauri#11992).
- Document `--codesign` flow in README §Bundle.
- Add a CI gate that fails `tauri:build` for macOS targets unless `APPLE_SIGNING_IDENTITY` env is set.

Track as a checklist item in the Phase 2 PR description.

---

## P3 — Nits

- `shell/src/app/page.tsx:51-55`: hardcoded `/create-chrome/` and `/parent/` href strings — should use `Link` from `next/link` (consistent with `layout.tsx`) so client-side nav doesn't full-reload.
- `shell/src/app/layout.tsx:17`: `className="dark"` on `<html>` with no light-mode toggle — fine but document that the kid app is dark-only.
- `shell/src/app/layout.tsx:20-29`: `<nav>` lacks `aria-label`. Add `aria-label={t("nav.aria_label")}` + key `nav.aria_label = "Nawigacja główna"`.
- `shell/src/app/page.tsx:48-56`: `<a href="#">` for `ZAGRAJ` — kid clicks and nothing happens. Add `onClick={(e)=>{e.preventDefault(); /* trigger sidecar */}}` + visual disabled state when `status !== "open"`. Currently confusing.
- `pl.json:5`: `"lang": "pl-PL"` is redundant with `LOCALE` const — pick one source of truth.
- `shell/src/messages/pl.json`: no `nav.aria_label`, no `bridge.reconnecting`, no `t.err.missing`. Add as part of P1-3/P0-2.
- `shell/src-tauri/src/lib.rs:8-10`: `shell_smoke` registered but never invoked by the frontend. Either invoke it from `layout.tsx` mount-effect to validate IPC, or remove.
- `shell/src-tauri/Cargo.toml:14, 19`: pin minor versions (`tauri = "2.1"` not `"2"`) for reproducible builds.
- `shell/eslint.config.mjs` not reviewed — confirm `eslint-config-next` flat config actually loaded (silent failure mode in v16).
- `globals.css:62`: `--destructive: oklch(0.704 0.191 22.216)` is voxel's red. Kid shell may want a softer red for "Powiedz Rodzicowi" overlays — not a blocker, raise with copilot.
- Accessibility: glitch-text uses `data-text` for `::before/::after` clones — screen readers will read the headline THREE times (real + 2 pseudo). Wrap pseudo-element content with `aria-hidden`-equivalent via `speak: never;` (CSS) or change clones to `content: ""` and use background-clip text instead. **Open a follow-up A11y task.**
- `scanlines::after { mix-blend-mode: overlay; }` — on Windows WebView2 < 120 this fell back to `normal`. Acceptable.
- `next.config.ts`: `trailingSlash: true` is correct for static export → Tauri custom-protocol path resolution. ✅

---

## Summary

| Sev | Count |
|-----|-------|
| P0  | 3     |
| P1  | 6     |
| P2  | 8     |
| P3  | 12+   |

**Top 3 to fix this week:**
1. Scope `shell:allow-open` to an allowlist (P0-1, 5-line patch).
2. Add reconnect + bounded cmd queue to `GodotBridge` (P0-2).
3. Token-gate the WS handshake before any real domain command lands (P0-3).

Re-review after P0-1..P0-3 patches.

— /Users/jakubsikora/Repos/choyce-engine/thoughts/shared/reviews/adv-tauri-quality-2026-05-22.md

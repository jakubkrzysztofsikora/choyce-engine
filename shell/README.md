# Choyce Engine — Shell (Tauri 2 + Next.js + Bun)

Kid-safe Polish-language Godot 4.6 game engine — **desktop shell**. Hosts the
landing screen, world library, parent zone, and create-chrome UI. Play mode
stays in Godot, launched as a Tauri sidecar and bridged over
`ws://127.0.0.1:9876`.

See: `../thoughts/shared/research/shell-architecture-2026-05-21.md`.

## Stack

- **Tauri 2.x** (Rust) — ~3-5 MB shell binary, WKWebView/WebView2/WebKitGTK.
- **Next.js 16** (App Router, `output: "export"`) — static export piped into Tauri.
- **Bun 1.3+** — package manager + dev runner.
- **Tailwind v4** — utility styling.
- **CSS extras lifted verbatim from VoxelForge** — see `src/app/globals.css`
  (glitch text, scanlines, neon lime glow, .shimmer, .rainbow-text).
- **Polish (`pl-PL`)** — default and only locale right now; strings live in
  `src/messages/pl.json` and load via `src/lib/i18n.ts`. `next-intl` upgrade
  lands when the routing model is finalized.

## Routes

| Path             | Component                               | Status                |
|------------------|-----------------------------------------|-----------------------|
| `/`              | `src/app/page.tsx`                      | Landing (ZAGRAJ / ZRÓB / RODZIC) |
| `/library/`      | `src/app/library/page.tsx`              | Stub                  |
| `/parent/`       | `src/app/parent/page.tsx`               | Stub                  |
| `/create-chrome/`| `src/app/create-chrome/page.tsx`        | Stub                  |

## Bridge to Godot

`src/lib/godot-bridge.ts` — TypeScript client. Connects to
`ws://127.0.0.1:9876` (the existing `TestBridgePort` from TASK-062, which the
research doc proposes to generalize into `ShellBridgePort`). Handshake +
heartbeat only for now. Real domain commands land in a follow-up PR.

Envelope shape (kid-safe, audit-friendly):

```jsonc
// client -> engine
{ "type": "cmd",   "id": 1, "command": "ping", "params": {} }

// engine -> client (ack)
{ "type": "ack",   "id": 1, "ok": true, "result": { "pong": true } }

// engine -> client (event)
{ "type": "event", "name": "session_end", "payload": { "elapsed_seconds": 3540 } }
```

## Dev

```bash
cd shell
bun install

# Frontend only (no Tauri window):
bun run dev          # http://localhost:3000

# Type-check + lint:
bun run check:types
bun run lint

# Build the static export (writes ./out):
bun run build

# Full Tauri dev (opens the desktop window, hot-reloads frontend):
bun run tauri:dev

# Production bundle (.app on macOS, .msi on Windows, .deb on Linux):
bun run tauri:build
```

## Lifted CSS

The VoxelForge brand-rot motifs (glitch text, scanlines, neon-lime glow,
shimmer, rainbow text) live verbatim in `src/app/globals.css` under the
banner `/* ===== VOXELFORGE BRAIN ROT CUSTOM STYLES ===== */`. Keep that
block in sync with the upstream voxel project when iterating on the look.

Choyce-specific additions (additive, do not remove):

- `.scanlines` — CRT scanline overlay.
- `.neon-lime` — `text-shadow` stack for lime glow on headings.
- `.bracket-cta` — `[ CTA ]` mono-uppercase button style.

## Constraints (do not violate in PRs)

- Polish strings: never inline in JSX; always via `t("…")` from
  `@/lib/i18n` so they migrate cleanly to `next-intl`.
- WebSocket bridge: localhost only (`127.0.0.1`). Never bind LAN.
- No `z-ai-web-dev-sdk` dependency, and no copy-paste from
  `~/Repos/personal/voxel/src/app/api/generate/route.ts`.
- Capability surface stays minimal — see `src-tauri/capabilities/default.json`.

## Status

Skeleton PR — Phase 1 of the 30-day plan in
`shell-architecture-2026-05-21.md`. Subsequent PRs:

1. Generalize `TestBridgePort` -> `ShellBridgePort` on the Godot side.
2. Spawn Godot as a Tauri sidecar (`shell:allow-spawn`,
   `Command::sidecar("play-engine").spawn()`).
3. Port `landing_screen.gd`, `world_picker_shell.gd`, `library_shell.gd`,
   `parent_zone_shell.gd`, `create_shell.gd` (chrome) to web.

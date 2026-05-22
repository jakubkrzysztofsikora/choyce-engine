---
date: 2026-05-21
researcher: deep-research-shell-arch
status: complete
---
# Research: Shell Architecture — Godot-Only vs Hybrid Desktop+Godot

## TL;DR
- **Current state**: Every screen (landing, world picker, create, parent zone, library, play) is a Godot `Control` scene driving tens of thousands of GDScript lines. UI flexibility for the requested phonk/sigma neon aesthetic (CSS-animated glitch text, lime glow shadows, gradient lockups) is bottlenecked by Godot's theming system.
- **Recommendation**: **GO** — split into a **Tauri + WebView shell** (landing/picker/library/parent zone/create-shell chrome) plus **Godot 4.6 sidecar process** for play (3D gameplay only, possibly create canvas), bridged by a **WebSocket IPC channel that reuses the existing `TestBridgePort` (TASK-062)**. The 3D play scene stays in Godot because HTML5/WebGL2 export has documented poor 3D performance on mobile, no C# (irrelevant here, we're GDScript), and audio latency issues.
- **Headline trade-off**: gain ~85% UI velocity (CSS+HTML+Vite hot reload for the neon aesthetic, real DOM accessibility / VoiceOver, Tauri bundle ~3-5 MB vs Electron ~150 MB), but pay with macOS code-signing two binaries (known Tauri sidecar notarization friction, [tauri#11992](https://github.com/tauri-apps/tauri/issues/11992)), an IPC contract to maintain, and a one-time port of ~30+ shells.
- **Hex-arch impact is net-positive**: Tauri commands map cleanly to new outbound ports (`TauriShellPort`, `SystemNotificationPort`); domain stays pure GDScript inside the Godot sidecar; existing ports survive untouched.
- **Alternatives ruled out**: Electron (bundle bloat — 80-200 MB shell on top of a 70-100 MB Godot export kills first-run install conversion for kids on parental wifi); native SwiftUI (locks out future Windows/Linux/iPad which the AAA-upgrade synthesis flagged as 2026/2027 targets); Web PWA via Godot HTML5 (3D perf cliff, mobile rendering bottlenecks, audio latency).

## Decision Framework

| Criterion | Weight | Why it matters here |
|-----------|--------|---------------------|
| Kid-safety isolation | 30% | Play sandbox must crash-isolate from parent zone; moderation + audit ledger boundaries; must enforce 60-min session timer even if play crashes. |
| UI velocity for phonk/neon aesthetic | 20% | User explicitly cited VoxelForge `globals.css` (glitch text, lime glow, CSS keyframe animation). Godot Theme/StyleBox cannot reproduce CSS `text-shadow: 0 0 16px #84ff00` with stacked blurs + animated glitch keyframes without per-pixel shaders for every label. |
| Hex-arch invariants | 15% | Domain + application layers must stay pure GDScript RefCounted (per memory: TASK-001/002). |
| Bundle size + install conversion | 10% | Kid downloads on parent's home wifi; >100 MB has measurable drop-off. |
| Update cadence | 10% | Shell ships weekly (neon UI tweaks, Polish copy), engine ships monthly (gameplay). Decoupling = faster shell iteration. |
| pl-PL + accessibility | 10% | Real DOM = real `lang="pl-PL"` + VoiceOver/NVDA out of box. Godot screen-reader story is weaker. |
| Cross-platform reach | 5% | M2 Max user today; plan flags iPad/Windows tomorrow. |

## Options

### A. Godot-only (status quo)
Every shell is a Godot `Control` scene. UI built with `Theme`, `StyleBoxFlat`, `Tween`, and shader materials on `Label`/`Panel`. Polish strings via `_t()`. Audio governance, audit ledger, moderation, RBAC all wired in `main.gd:200`.

- **Pros**: Single binary, single hex-arch composition root, no IPC, single code-signing identity. Existing 27+ done tasks invested here.
- **Cons**: Reproducing the VoxelForge aesthetic (CSS keyframe glitch, layered text-shadows, gradient text-fills, container queries for responsive layout) requires custom `_draw()` overrides + shader materials on every label; no DOM accessibility tree; theming changes need engine rebuild. AAA-synthesis review already flagged UI polish as the weakest dimension.
- **Examples shipping this**: Brotato (GameMaker), Vampire Survivors (Phaser → native), Buckshot Roulette (Godot 4). All have minimalist UI — none ship the kind of animated glitch/neon aesthetic the user is targeting.

### B. Tauri (Rust + WebView) shell + Godot sidecar for play **[RECOMMENDED]**
Tauri 2.x ships ~3-5 MB installer that hosts a WebView (WKWebView on macOS, WebView2 on Windows, WebKitGTK on Linux). Tauri's `externalBin` declares the Godot export as a [sidecar](https://v2.tauri.app/develop/sidecar/); shell spawns it on "Play" with `Command.sidecar('binaries/play-engine').spawn()`, parses stdout for `GODOT_LISTENING port=…`, opens WebSocket back. Frontend is Vite + Svelte/SolidJS/React (whichever) with the full VoxelForge `globals.css` aesthetic available verbatim.

- **Pros**: ~25× smaller shell than Electron ([PkgPulse 2026 benchmarks](https://www.pkgpulse.com/blog/best-desktop-app-frameworks-2026)); ~50 MB RAM idle vs Electron's 150-300 MB; sub-second startup; Rust backend gives a sandboxed seam for the audit ledger / parental control vault; declarative capability model (`shell:allow-spawn` only for the Godot sidecar, `http` only for `127.0.0.1:<port>`); CSS animations + DOM accessibility free; mobile WebView story (Tauri 2 supports iOS/Android) keeps the iPad door open.
- **Cons**: WebView rendering can subtly differ between WKWebView (macOS) and WebView2 (Windows) — minor for our use case; Rust compile time slower than JS toolchain; **macOS sidecar notarization has a known open bug** ([tauri#11992](https://github.com/tauri-apps/tauri/issues/11992)) — workaround is manual `codesign --deep --options runtime --entitlements ...` on the Godot binary before bundling.
- **Examples shipping this**: Fluxzy (.NET sidecar under Tauri, [migration writeup](https://www.fluxzy.io/resources/blogs/electron-to-tauri-migration-fluxzy-desktop)); Helix Editor (Tauri shell + Rust core); growing 55% YoY on GitHub.

### C. Electron + Godot sidecar
Same pattern as B but with Electron. Electron ships full Chromium + Node.js in every binary.

- **Pros**: Most mature ecosystem; `electron-builder` has battle-tested macOS notarization + entitlements pipeline (proven by Datasette Desktop, Slack, VSCode); identical Chromium rendering across all OSes; Node.js main process is a natural place to manage the sidecar.
- **Cons**: 80-200 MB installer **before** adding the ~80-100 MB Godot export — easily ships 250+ MB to parents' machines; 150-300 MB RAM idle while a 3D game runs in the sibling process; ecosystem growth has plateaued.
- **Examples shipping this**: RPG Maker MV/MZ community-built Electron wrapper ([Plugin MZ Electron For Mz](https://en.plugin-mz.fungamemake.com/archives/10749), [Steam Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2803029711)); VSCode, Discord, Slack, Figma desktop.

### D. Web PWA (Godot HTML5 export served by Vite, no native shell)
Ship choyce-engine as a PWA. Godot's HTML5 export becomes the play canvas inside a `<canvas>` tag; shell is the same Vite app deployed both as desktop PWA and web.

- **Pros**: Zero installation friction; trivial update cadence (server-side); File System Access API gives "save-to-folder" UX similar to Construct 3 ([Construct 3 case study](https://developer.chrome.com/blog/how-construct3-uses-the-file-system-access-api)).
- **Cons**: **Hard cliff for 3D**. Documented HTML5 performance issues — desktop 200-250 fps drops to 15-20 fps in HTML5 ([godot-proposals#4013](https://github.com/godotengine/godot-proposals/discussions/4013)); poor mobile rendering ([godot#58836](https://github.com/godotengine/godot/issues/58836)); single-threaded by default in Godot 4.3+ unless PWA service-worker COOP/COEP headers are wired; audio latency in single-threaded mode; **no IndexedDB story for our encrypted parental policy vault**; no `OS.get_environment` (already abstracted via `EnvironmentPort`, so this point is moot, but still — many adapters would need web variants).
- **Examples shipping this**: Construct 3 editor (browser-only since 2020); poki.com, itch.io HTML5 titles. None of them are 3D AAA-aspiring.

### E. Native SwiftUI shell + Godot sidecar
Use SwiftUI on macOS, spawn Godot via Apple's new [`swift-subprocess`](https://github.com/swiftlang/swift-subprocess).

- **Pros**: Best-in-class native macOS feel (VoiceOver, Stage Manager, Sonoma blur), zero WebView quirks, smallest possible shell binary (~1-2 MB), Apple Notarization is trivial for a SwiftUI app.
- **Cons**: macOS-only — kills the iPad/Windows/Linux ports the AAA-synthesis flagged; doubles eventual code paths if cross-platform is needed; cannot reproduce CSS keyframe glitch animations declaratively (SwiftUI animation engine is good but the user's reference asset is literally CSS); team-skill mismatch (project is GDScript + Python today).
- **Examples shipping this**: NetNewsWire, Ivory, Tot — all minimalist productivity apps, not game-creation platforms.

## Comparison Matrix

| Criterion (weight) | A: Godot-only | B: Tauri+Godot | C: Electron+Godot | D: Web PWA | E: SwiftUI+Godot |
|---|---|---|---|---|---|
| Kid-safety isolation (30%) | 6 — same process, crash kills shell | **9** — sidecar crash leaves shell alive, parent zone reachable | 9 — same as B | 5 — single tab; crash = white screen | 9 — same as B |
| UI velocity for neon aesthetic (20%) | 4 — every glitch effect = custom shader | **10** — paste `globals.css` verbatim | 10 — same as B | 10 — same | 6 — SwiftUI animation, not CSS keyframes |
| Hex-arch invariants (15%) | 9 — already pure | **9** — Tauri commands become new outbound ports | 9 — same | 7 — many adapters need web variants | 9 — same as B |
| Bundle size / install (10%) | 8 — single 80-100 MB Godot export | **9** — 3-5 MB shell + 80-100 MB engine | 4 — 150 MB shell + 80-100 MB engine | 10 — zero install | 10 — 1-2 MB shell + engine |
| Update cadence (10%) | 5 — every shell tweak = full rebuild | **9** — shell auto-update independent of engine | 9 — same | 10 — server-side | 7 — App Store review |
| pl-PL + accessibility (10%) | 5 — Godot screen-reader weak | **9** — DOM + `lang="pl-PL"` + ARIA | 9 — same | 9 — same | 9 — VoiceOver |
| Cross-platform reach (5%) | 9 — Godot exports everywhere | **8** — Tauri 2 covers macOS/Win/Linux/iOS/Android | 7 — desktop only | 10 — anywhere with WebGL2 | 1 — macOS only |
| **Weighted total** | **6.4** | **9.1** | **8.0** | **7.7** | **7.7** |

## IPC Pattern (for the recommended Tauri+Godot hybrid)

Leverage the existing **`TestBridgePort` (TASK-062)** — it already runs an HTTP debug server on `127.0.0.1:9876` gated by `debug_test_bridge`. Upgrade path:

1. **Generalize the bridge into `ShellBridgePort`** (outbound port, new file `src/ports/outbound/shell_bridge_port.gd`). Methods: `start_server(port: int) -> int` (returns actual port), `send_event(event_type: String, payload: Dictionary)`, `register_command(name: String, handler: Callable)`.
2. **`WebSocketShellBridgeAdapter`** implements via `WebSocketMultiplayerPeer.create_server(0)` ([Godot 4.4 docs](https://docs.godotengine.org/en/4.4/classes/class_websocketmultiplayerpeer.html)). Binds `127.0.0.1` only (kid-safety: never expose to LAN).
3. **Sentinel handshake**: Godot prints `CHOYCE_LISTENING port=%d` to stdout on `_ready()`. Tauri Rust tail reads it via [`Command::sidecar`](https://v2.tauri.app/develop/sidecar/), `emit("godot-ready", { port })` to frontend.
4. **JSON protocol** (kid-safe, audit-friendly):
   ```
   { "type": "cmd", "id": 1, "name": "start_play", "args": { "world_id": "uuid", "kid_profile_id": "uuid" } }
   { "type": "event", "name": "session_end", "stats": { "elapsed_seconds": 3540, ... } }
   { "type": "ack", "id": 1, "ok": true }
   ```
5. **Audit ledger sync**: each `cmd` and `event` gets appended to the audit ledger inside Godot (existing hash-chain code, TASK-019), then mirrored to a Tauri-side SQLite snapshot for parent zone read-model queries while engine is offline.
6. **Lifecycle**: shell sends `{"type":"cmd","name":"quit"}` on window close; SIGTERM after 2 s timeout; Tauri tracks `Child` handle to avoid orphan processes (per [Tauri sidecar docs](https://v2.tauri.app/develop/sidecar/) — orphan cleanup is the caller's responsibility).

## Migration Cost

Inventory of current Control scenes (from `git status` + memory):
- `landing_screen.gd` — port to web (mascot, CTA buttons, voice prompt).
- `world_picker_shell.gd` — port to web.
- `create_shell.gd` (34 i18n keys per memory) — port shell chrome to web; canvas builder stays in Godot (Phase 2 below).
- `play_shell.gd` (14 i18n keys) — Godot only, but launch parameters cross IPC.
- `parent_zone_shell.gd` — port to web (RBAC role assert moves to Rust capability check).
- `library_shell.gd` — port to web (server-side RBAC stays in Rust; reads from SQLite snapshot of `PublishStore`).

### 30-day plan (Phase 1: prove the IPC, no migration)
- Stand up `pnpm create tauri-app` next to `choyce-engine/`; Vite + SolidJS + the VoxelForge `globals.css`.
- Implement `ShellBridgePort` + `WebSocketShellBridgeAdapter` (port of TASK-062, ~200 LOC).
- Tauri spawns existing Godot binary, opens WS, exchanges a single `ping`/`pong`.
- Wire a "demo landing page" in Tauri that launches `play_shell` directly.
- Quality gate: AI vision runner (TASK-063) confirms the shell looks like the VoxelForge mockup; existing Godot AI scenarios still pass.

### 60-day plan (Phase 2: shell migration)
- Port landing + world picker + library to Tauri (highest UI-flex value, lowest gameplay coupling).
- Parent zone migration (RBAC role check moves to Tauri capabilities + Rust-side audit reads).
- Create-shell chrome to Tauri; **keep create canvas builder in Godot** (it needs the same 3D viewport gameplay uses).
- COPPA export/delete: Tauri-side file-picker handles ZIP output; Godot pushes data over IPC.

### 90-day plan (Phase 3: polish + auto-update)
- Tauri auto-updater (full-binary, ~3 MB diff — fast for kids on home wifi).
- iPad TestFlight via Tauri 2 mobile.
- Retire `landing_screen.gd`, `world_picker_shell.gd`, `library_shell.gd`, `parent_zone_shell.gd`, `create_shell.gd` (chrome only). Memory entries close.

**Hex-arch invariants preserved:**
- Domain (RefCounted), Application services, Inbound ports — **zero change**, stay in Godot.
- Outbound ports gain two new adapters: `WebSocketShellBridgeAdapter` (Godot side), `TauriShellAdapter` (TS side, talks to backend services).
- Audit ledger remains source-of-truth inside Godot; Tauri SQLite is a read-model cache (eventually consistent, COPPA-compliant because original is in Godot).

**Hex-arch invariants that change:**
- Composition root splits: Godot composition root (`main.gd:200`) stays for play + bridge; Tauri composition root (`src-tauri/src/main.rs`) wires shell-side services (file pickers, OS notifications, auto-update).
- Memory's `Wave B Phase 1: composition-root CI gate workflow` needs extension to cover both composition roots.

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| macOS sidecar notarization bug ([tauri#11992](https://github.com/tauri-apps/tauri/issues/11992)) | High | Manually sign Godot binary with `codesign --deep --options runtime --entitlements ./Entitlements.plist` before Tauri bundling; bake into CI; budget 2 days for first run. |
| Audit ledger split between Godot + Tauri SQLite | High | Godot remains source-of-truth; Tauri snapshot is read-only cache; hash chain (TASK-019) still validates the truth. |
| Kid bypasses pause: shell pauses but engine keeps running | High | Bridge `pause` cmd is required; engine sets `get_tree().paused = true` immediately on receipt; Tauri kills child after 5 s if no ack. |
| WebView quirks across macOS/Windows | Medium | CI runs Playwright tests on both WKWebView (macOS GitHub Actions) + WebView2 (Windows runner); existing AI vision runner extends to cover the Tauri shell. |
| Orphan Godot processes if shell crashes | Medium | Tauri tracks `Child` handle; OS-level subprocess reaper as fallback (`prctl(PR_SET_PDEATHSIG)` on Linux, `setpgid` + `kill(0)` on macOS). |
| pl-PL fonts in WKWebView vs WebView2 differ | Low | Bundle a single web font (e.g., Inter or Lexend, both have full Latin Extended); set `font-display: swap`. |
| Code-signing two binaries doubles CI surface | Low | Same Developer ID Application certificate signs both; one Apple Team ID, one notarization submission for the outer `.app` bundle that contains the inner Godot binary. |
| Tauri shell rendering bug freezes the kid mid-game | Low (engine keeps running independently) | Engine sends `heartbeat` every 5 s; if shell missed 3 heartbeats, engine shows its own "Parent, the screen froze — open the launcher again" prompt. |

## Recommendation

**GO** with **Option B (Tauri + WebView shell + Godot 4.6 sidecar for play)**.

Pull the trigger now because:
1. The AAA-upgrade synthesis already flagged UI polish as the weakest dimension; CSS+DOM unlocks the entire VoxelForge aesthetic verbatim.
2. The existing `TestBridgePort` (TASK-062) is 80% of the IPC layer — already debug-flag-gated, already isolated to `127.0.0.1`, already JSON.
3. Hex-arch survives the split with **zero domain/application changes** — only new outbound ports.
4. Bundle/RAM characteristics fit a kid-safe install funnel (small shell, contained engine, sandboxed audit ledger).
5. Tauri 2's iOS/Android story future-proofs the iPad path that the synthesis already named.

**Do not** pick Electron — the 150-300 MB RAM floor on top of a 3D Godot game is a non-starter on the Mac mini M2 baseline the project nominally targets.

**Do not** pick SwiftUI — it kills cross-platform, and the user already invested in GDScript+Python multi-agent infrastructure.

## Sources

- [Tauri vs Electron 2026: bundle, RAM, benchmarks — PkgPulse](https://www.pkgpulse.com/blog/best-desktop-app-frameworks-2026)
- [Tauri vs Electron 2026: 96% Smaller Apps — Tech Insider](https://tech-insider.org/tauri-vs-electron-2026/)
- [Tauri vs Electron — Rustify 2026](https://rustify.rs/articles/rust-tauri-vs-electron-2026)
- [Tauri vs Electron — Hopp.app trade-offs](https://www.gethopp.app/blog/tauri-vs-electron)
- [Electron vs Tauri — DoltHub Blog](https://www.dolthub.com/blog/2025-11-13-electron-vs-tauri/)
- [Electron-to-Tauri migration — Fluxzy](https://www.fluxzy.io/resources/blogs/electron-to-tauri-migration-fluxzy-desktop)
- [Tauri Sidecar / Embedding External Binaries (v2)](https://v2.tauri.app/develop/sidecar/)
- [Tauri Shell Plugin (v2)](https://v2.tauri.app/plugin/shell/)
- [Tauri macOS Code Signing](https://v2.tauri.app/distribute/sign/macos/)
- [Tauri sidecar notarization bug #11992](https://github.com/tauri-apps/tauri/issues/11992)
- [Shipping a Production macOS App with Tauri 2.0 — dev.to](https://dev.to/0xmassi/shipping-a-production-macos-app-with-tauri-20-code-signing-notarization-and-homebrew-mc3)
- [Electron Inter-Process Communication docs](https://www.electronjs.org/docs/latest/tutorial/ipc)
- [Electron Forge macOS code-signing guide](https://www.electronforge.io/guides/code-signing/code-signing-macos)
- [Simon Willison — Signing and notarizing an Electron app](https://til.simonwillison.net/electron/sign-notarize-electron-macos)
- [Godot 4 — Embedding in another desktop app (forum)](https://forum.godotengine.org/t/embed-godot-in-another-desktop-app/41969)
- [Godot 4 — WebSocketMultiplayerPeer API](https://docs.godotengine.org/en/4.4/classes/class_websocketmultiplayerpeer.html)
- [Godot 4 — WebSocket tutorial](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html)
- [Godot 4 — Command line tutorial](https://docs.godotengine.org/en/4.4/tutorials/editor/command_line_tutorial.html)
- [Godot — Web platform export (DeepWiki)](https://deepwiki.com/godotengine/godot-docs/7.4-web-platform-export)
- [Godot — Exporting for the Web](https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_web.html)
- [Godot HTML5 mobile performance issue #58836](https://github.com/godotengine/godot/issues/58836)
- [Godot HTML5 performance discussion #4013](https://github.com/godotengine/godot-proposals/discussions/4013)
- [Godot — PWA export proposal #1269](https://github.com/godotengine/godot-proposals/issues/1269)
- [Godot remote debugger walkthrough — Aceade](https://aceade.net/2025/07/17/godot-how-to-use-remote-debugger/)
- [RPG Maker MV/MZ Electron deploy guide (Steam macOS)](https://steamcommunity.com/sharedfiles/filedetails/?id=2803029711)
- [RPG Maker MV/MZ Electron deploy guide (Steam Windows)](https://steamcommunity.com/sharedfiles/filedetails/?id=2793715885)
- [Plugin MZ — Electron For Mz](https://en.plugin-mz.fungamemake.com/archives/10749)
- [ElectronMV — Electron wrapper for RPG Maker MV (GitHub)](https://github.com/quxios/ElectronMV)
- [Construct 3 and the File System Access API — Chrome Developers](https://developer.chrome.com/blog/how-construct3-uses-the-file-system-access-api)
- [Construct 3 — supported in all major browsers (official blog)](https://www.construct.net/en/blogs/construct-official-blog-1/construct-supported-major-893)
- [Construct 3 — Exporting to Windows with WebView2 wrapper](https://www.construct.net/en/tutorials/exporting-windows-webview2-2685)
- [Roblox Engine architecture (Fandom wiki)](https://roblox.fandom.com/wiki/Engine)
- [Apple Swift Subprocess pitch (Swift Forums)](https://forums.swift.org/t/pitch-swift-subprocess/69805)
- [Swift 6.2: Subprocess — Michael Tsai](https://mjtsai.com/blog/2025/10/30/swift-6-2-subprocess/)
- [jamf/Subprocess (Swift, GitHub)](https://github.com/jamf/Subprocess)

Report by deep-research-shell-arch, ready for synthesis.

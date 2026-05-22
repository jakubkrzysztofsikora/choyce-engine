# Adversarial Perf Review — Tauri/VoxelForge pivot

Range: `eeaeebd..f683184` (7 commits). Target: 60 fps M2 Max + iPad.

## Critical

### C1 — CRT scanline shader runs every frame, full-screen, no kill switch
`src/adapters/inbound/main.gd:135-154`. `VoxelScanlines` ColorRect set to `PRESET_FULL_RECT`, canvas_item fragment shader executes on every pixel every frame. On a 3440×1440 = 5.0 Mpx display: ~300 Mfrag/s. iPad retina 2732×2048 = 5.6 Mpx → 336 Mfrag/s. Cost is small on M2 Max GPU (<0.3 ms) but on integrated/tablet GPUs this is real fill-rate competing with 3D scene + UI overdraw. No `intensity=0` switch when a11y "reduce motion" is enabled.
**Patch:** bind `intensity` uniform to AccessibilityPolicy.reduce_motion; set `visible=false` when zero. Also add `light_only=false` + `unshaded` already implicit on canvas_item — fine.

### C2 — Polyhaven 6.2 MB HDRI loaded synchronously on combat entry
`src/adapters/inbound/gameplay/world_renderer.gd:418` — `ResourceLoader.load(_COMBAT_HDRI_PATH)` is blocking. 6.2 MB .hdr decode + GPU upload → 80–200 ms frame stall when kid enters combat mode. iPad worse (slower I/O).
**Patch:** `ResourceLoader.load_threaded_request` at world setup, poll via `load_threaded_get_status` before transitioning shell; or preload at autoload _ready behind a feature flag.

## High

### H1 — WS adapter polls every frame regardless of activity
`src/adapters/outbound/websocket_shell_bridge_adapter.gd:128-133`. `_accept_incoming` + `_service_peer` + `_tick_heartbeat` run at 60 Hz even when no peer is connected. Cheap individually (~10 µs) but unnecessary. `_active=false` early-return is fine; when shell connected the per-frame `_peer.poll()` plus `get_available_packet_count` is ~0.02 ms/frame.
**Patch:** Move polling to a Timer at 30 Hz (kid input latency tolerant), or use `set_process(false)` when no peer accepted. Heartbeat tick already uses delta accum so frequency reduction is safe.

### H2 — Tauri heartbeat 5 s × 12/min on idle shell
`shell/src/lib/godot-bridge.ts:27` `HEARTBEAT_INTERVAL_MS = 5_000`. Kid app spends most time idle. 12 RTT/min × WS frame + JSON parse on Godot side = useless wakeups breaking power gating on iPad. 3-miss × 5 s = 15 s detection window is fine even at 15 s interval.
**Patch:** bump to 15_000 ms, leave timeout 2_000. Saves ~70% of idle WS traffic.

## Medium

### M1 — `_voxel_panel_style` allocates fresh StyleBoxFlat per panel per theme apply
`src/adapters/inbound/scenes/play/play_shell.gd:693-748`. Called 3× in `_apply_theme` (side, minimap, session_end) plus per-button at `_voxel_style_button`. Theme reapply on every shell show. ~6–10 StyleBoxFlat allocs per play entry. Not per-frame, but creates churn on shell transitions.
**Patch:** Cache `_lime_panel_sb`, `_glow_panel_sb`, `_yellow_panel_sb` as `var` on the shell, build once in `_ready`. Same for buttons.

### M3 — Audio scan blocking I/O on autoload `_ready`
`src/adapters/inbound/shared/audio/audio_bank.gd:65,224-237`. `DirAccess.open` + `list_dir_*` on `res://data/audio/music/voxel/`. 10 .mp3 files currently (counted). Cost ~1–3 ms cold-cache. Acceptable now; will scale linearly with library growth. Worth marking as known-bounded.
**Patch:** none required at current size. If library grows past ~50 tracks, push scan to `WorkerThreadPool` + emit signal when ready.

### M4 — Phonk index rotation is fine (O(1)), but bias is wrong
`audio_bank.gd:133-141`. `_voxel_phonk_slugs` rotation uses `randi() % size` then nudges off `_last_phonk_index`. O(1), no linear scan. Minor: with N=2 the "+1 mod N" path always picks the non-last one → strict alternation, not random. Cosmetic, not perf.

### M5 — Body bg ColorRect overdraw
`main.gd:126-132`. Full-rect opaque ColorRect at z=0 then VoxelScanlines at z=1 then Layout above. Existing shells already paint their own backgrounds → double-fill at full screen. On M2 Max negligible (<0.1 ms). On iPad measurable on memory-bandwidth-bound GPU.
**Patch:** keep — needed for VoxelForge dark surface. But check shells aren't ALSO painting opaque BGs (audit pass on landing_screen / create_shell backgrounds).

## Low

### L1 — Fonts: 3 new TTFs (Rubik Glitch ~80 KB, Audiowide ~50 KB, Rajdhani ~120 KB) added to data/fonts/voxel/. Glyph cache is per-size + per-variant. With NavBar h2/h3 + button sizes that's ~6 cache buckets. Memory <2 MB total. Not a concern.

### L2 — `_process(delta)` in main.gd:93 iterates `_ports.values()` checking `has_method("flush_if_due")` every frame. Dictionary iter ~25 ports × `has_method` reflection = ~5 µs. Negligible but trivially fixable: build `_flushable_ports: Array` once at compose time.

## Summary
2 Critical (CRT shader a11y kill-switch, HDRI threaded load), 2 High (WS poll throttle, Tauri heartbeat 5→15 s), 5 Medium/Low.

Report path: `/Users/jakubsikora/Repos/choyce-engine/thoughts/shared/reviews/adv-perf-pivot-2026-05-22.md`

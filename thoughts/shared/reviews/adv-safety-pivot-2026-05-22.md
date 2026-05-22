# Adversarial Kid-Safety + COPPA Review — Shell Pivot

Range: `eeaeebd..f683184` (main). Reviewer: hostile.

7 commits, ~+25k LOC. Net direction: Tauri shell, WS bridge, KayKit/Quaternius rigs, Audiowide/Rajdhani/Rubik Glitch fonts, "phonk/sigma aesthetic", 10 CC0 phonk tracks, real HDRI.

## Critical (release blockers)

### C1. STT moderation gate falsely PASSes every imported phonk track
File: `scripts/audio/moderate_imported_music.py:160-204` + `data/audio/music/voxel/.transcripts/*.txt` (all 10 files: **0 bytes**).

Pipeline contract claims "ElevenLabs STT → rules_pl.json scan". Reality:
- All 10 cached transcripts are empty files.
- `_process_track()` reads the empty cache (`source="cache"`) and short-circuits before any STT call.
- `_scan_for_blocked()` returns `[]` for empty input → verdict = `PASS` ("Instrumental — no lyrics detected", line 197-198).
- `MODERATION_LOG.md` shows 10/10 PASS but only because nobody ever ran the gate with a working key.

Combined effect: tracks named `tokyo_trap`, `whiskey_thoughts`, `faded_empires`, `the_visitor`, `hahavoid_type_beat` (all phonk genre — frequently feature crowd-shouts, sirens, gun-cock samples, drug/alcohol ad-libs) shipped to a 5-8 yo audience with **zero lyric verification**. The empty-transcript heuristic is also wrong for vocal-chopped phonk: a 200ms "ay" sample may not transcribe but is not "instrumental".

Patch (minimal):
```python
# moderate_imported_music.py:160
cached = _cached_transcript(mp3)
if cached is not None and cached.strip() == "":
    cached = None  # Empty cache = no decision; force re-STT.
if cached is not None:
    transcript = cached
    source = "cache"
elif dry_run:
    return {"file": mp3.name, "verdict": "REJECT",
            "reason": "No transcript and dry-run — refuse to certify",
            "transcript_excerpt": "", "hits": [], "source": "skip(dry-run)"}
```
Plus: re-run with a real key, OR add an audio-event classifier (ElevenLabs `tag_audio_events=true` — currently disabled at line 126) to flag sirens / gunshots / crowd-shout samples that STT silences. Pull `tokyo_trap.mp3` + `whiskey_thoughts.mp3` until certified.

### C2. WS bridge has no origin check, no auth, no token — same-machine SOP bypass
File: `src/adapters/outbound/websocket_shell_bridge_adapter.gd:136-167`, `shell/src-tauri/tauri.conf.json:csp`.

`127.0.0.1` binding does not protect against:
- Any other process on the kid's machine (sibling Electron app, browser extension, npm `postinstall` script) opening `ws://127.0.0.1:9876`.
- Any webpage in any browser the parent has open: WebSocket handshake is **not** subject to Same-Origin Policy. A malicious site can `new WebSocket("ws://127.0.0.1:9876")` and the Godot bridge will accept it (line 143-150 calls `accept_stream` unconditionally).
- The CSP at `tauri.conf.json` whitelists `ws://127.0.0.1:9876` only for the shell WebView — but the Godot server doesn't enforce that the client *is* the shell.

`_dispatch_envelope` accepts `request_kid_status` with arbitrary `profile_id` (line 254-259). Profile IDs are deterministic (likely `kid-default` / `<child-name>` from `KidStatusReadModelAdapter._projects`). A drive-by attacker enumerates 5 common profile IDs → exfils `title`, `progress_pct`, `last_played`, `session_count`, `collectibles_found`, `achievements_earned` per kid project. **COPPA personal information of a child under 13.**

Patch:
1. Add HMAC token: shell writes `~/.choyce/bridge.token` (random 32B) on Tauri startup; Godot reads same file at adapter init; reject envelopes whose first frame is not `{"command":"auth","params":{"token":"<hex>"}}`.
2. Reject `Origin` headers that aren't `tauri://localhost` or absent (Tauri WebView sends none; real browsers send Origin).
3. Drop `request_kid_status` from the bridge command surface entirely — read-model belongs to the inbound Godot side, not a Tauri shell that doesn't render the kid's HUD.

### C3. Bridge opens even if audit ledger fails — silent surveillance bypass
File: `websocket_shell_bridge_adapter.gd:97-111` + `:295-314`.

`start()` flips `_active = true` (line 109) **before** `_audit_open_event()` (line 110). `_audit_open_event` ignores the return value of `_audit_ledger.append_record(record)` (line 314 — `FilesystemAuditLedger.append_record` returns `bool` per `:95`). If the ledger is unavailable, mid-rotation, or fails hash-verification, the bridge accepts shell traffic with **no audit trail**. Combined with C2, a malicious local actor opens the bridge while the parent's audit panel shows nothing.

Patch:
```gdscript
func start() -> bool:
    if not _gate_open(): return false
    _tcp_server = TCPServer.new()
    if _tcp_server.listen(_port, BIND_ADDRESS) != OK:
        _tcp_server = null; return false
    if not _audit_open_event():   # fail-closed
        _tcp_server.stop(); _tcp_server = null; return false
    _active = true
    return true

func _audit_open_event() -> bool:
    if _audit_ledger == null: return false
    ...
    return _audit_ledger.append_record(record)
```

## High

### H1. Mouse-capture trap on session start contradicts its own comment
File: `src/adapters/inbound/gameplay/gameplay_runtime.gd:165-170`.

Comment block says "Don't capture mouse — kid needs to click ESC button … Mouse capture made the apparent 'hang' feel total since user couldn't escape." Two lines later: `Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)`. The comment was preserved while the behaviour was inverted. Kid who triggers this during voice/AI overlay can't click parent's "stop session" button (overlay TTS swallows audio focus, cursor is invisible). Two-press ESC mitigation (line 1183) helps but requires keyboard literacy a 5yo may not have. Either uncapture by default or auto-uncapture on any UI CanvasLayer becoming visible.

### H2. Tauri shell allows `style-src 'unsafe-inline'`
File: `shell/src-tauri/tauri.conf.json:18`.

`style-src 'self' 'unsafe-inline'` — Next.js + Tailwind likely require it, but `unsafe-inline` styles + a hijacked WS bridge (C2) lets an attacker render arbitrary overlays in the shell WebView reading kid PII delivered over WS. `script-src 'self'` correctly omits `unsafe-inline`/`unsafe-eval`, good — but harden style-src via nonces (Next.js 15 supports it) before shipping to families.

## Medium

### M1. Camera-direction attack ray strips vertical aim
File: `src/adapters/inbound/gameplay/player_controller.gd:407-415`. `cam_fwd.y = 0.0` (line 411) projects to ground plane. Kid looking 45° up or down still attacks horizontally — feels off but not unsafe. Edge case: enemies above on a platform are technically attackable from below (`global_position` horizontal check at 422-433 ignores Y entirely). Adds an off-screen-attack vector against airborne enemies. Kid-safety = attacks should be visible; clamp by including Y in the to_enemy angle test.

### M2. `tag_audio_events=false` on STT call disables the ONE feature that catches sirens/gunshots
File: `scripts/audio/moderate_imported_music.py:126`. Even if C1 is fixed, instrumental tracks slip through because audio-event tags are off. Set to `true`, parse the returned tags, reject on `siren`, `gunshot`, `crowd_shouting`, `explosion`, `glass_break`, `scream`.

### M3. Phonk aesthetic + 5-8yo audience — content-policy alignment
Genre association: phonk/drift-phonk has cultural ties to Memphis rap (drugs/violence themes) and "sigma male" / TikTok aggro-male content. Even with clean lyrics, the audio fingerprint primes older-kid YouTube algorithms once recorded gameplay is uploaded by parents. Not a code bug — flag for product review. Filenames (`tokyo_trap`, `whiskey_thoughts`, `hahavoid_type_beat`) reinforce this. Re-name to neutral slugs (`drive_01`, `night_loop_02`) regardless of moderation outcome.

## Low

### L1. `Quaternius/ninja.glb` is enemy/NPC role, not player
File: `src/adapters/inbound/gameplay/world_renderer.gd:65`, `gameplay_runtime.tscn:11` (player still `kenney/.../character-male-a.glb`). The "bunny→ninja swap" concern raised in scope does not apply to the player avatar. However, `ninja` role is the only Quaternius rig wired by default and enemy spawns may pick it. A 5yo reading "ninja with red headband + slit eyes" as scary is plausible. Mitigate by defaulting enemy role to `wojownik` or `szkielet` (already neutral) and gating `ninja` behind parent control.

### L2. Bridge `_next_request_id` overflows after `INT64_MAX` requests
Cosmetic; reachable only after centuries of heartbeats. Mention for completeness.

### L3. Bridge accepts envelopes without size limit
`get_packet()` (line 165) → `get_string_from_utf8` with no length check. A malicious local actor (per C2) can stream a 1 GB envelope and OOM-crash the Godot process during a kid's session. Cap to e.g. 64 KB before parsing.

---

## Summary

3 Critical, 2 High, 3 Medium, 3 Low. **The shell-bridge pivot landed a network surface, a content surface (phonk + ninja), and an audit surface — and the moderation gate that was supposed to certify the content surface is a no-op.** Recommend: block release on C1+C2+C3 fixes, treat H1 as next sprint, defer M3 to product.

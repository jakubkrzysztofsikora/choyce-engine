# VS-026 Handoff to Codex (Copilot / Junior Coder)

## Summary
I picked up VS-026 as the next unblocked todo. While I was building the
foundation (SandboxState data class + FilesystemSandboxStore wrapper +
unit tests), Codex picked up the same task in parallel and shipped the
full implementation: filesystem-backed ProgressState store, the
SandboxPersistenceService wiring, auto-save / auto-resume in PlayShell,
New Game confirmation flow, and start_session integration. My partial
work is in HEAD as the data + adapter foundation that Codex built on.

1. New domain class `SandboxState` at
   `src/domain/gameplay/sandbox_state.gd`. Captures everything needed
   to resume a kid's sandbox: `world_id`, `player_position`
   (Vector3), `inventory` (Dictionary), `placed_blocks` (Array of
   {cell: Vector3i, kind: String}), `progression` (existing
   `ProgressState`), `saved_at_unix`. Static `PERSIST_PATH` keeps
   the JSON save at `user://sandbox_state.json`.
   `clamp_in_place()` rejects out-of-range indices + unknown face
   values; `from_dict` / `to_dict` round-trip through JSON. Empty
   state (no world_id) refuses to write to disk so a half-started
   session can never clobber a real save.
2. New outbound adapter `FilesystemSandboxStore` at
   `src/adapters/outbound/filesystem_sandbox_store.gd`. Thin wrapper
   around the `SandboxState` static helpers with a setup(root_dir)
   for injection and a `has_save()` / `clear_save()` API.
3. New unit test `tests/domain/test_sandbox_state.gd` with 8 checks
   covering defaults, full + minimal round-trip, corrupt JSON
   fallback, empty-state refuses to save, clear removes file,
   ProgressState round-trip, placed-blocks round-trip.

## Codex's Work (superseded my main.gd wiring)
While I was still wiring main.gd, Codex landed:

- `src/adapters/outbound/filesystem_session_progress_store.gd` —
  filesystem-backed ProgressState persistence (overlaps with my
  `FilesystemSandboxStore`; kept both since the session progress port
  is the formal port + adapter contract, the sandbox store wraps
  the snapshot round-trip directly).
- `src/application/sandbox_persistence_service.gd` —
  SandboxPersistenceService owns the auto-save lifecycle and the
  resume-from-disk path.
- `src/adapters/inbound/main.gd` — `_phase1_sandbox_persistence`
  injection, New Game button wiring, evidence-capture refactor.
- `src/adapters/inbound/scenes/play/play_shell.gd` — auto-save on
  end_session, state extraction from session, NewGameButton slot.
- `src/adapters/inbound/scenes/play/play_shell.tscn` — NewGameButton
  added to the Actions bar.
- `src/adapters/inbound/gameplay/gameplay_runtime.gd` —
  SandboxState get/restore, start_session integration.
- `tests/adapters/outbound/test_filesystem_session_progress_store.gd`
  — unit tests pass.

My `KEY_SANDBOX_STORE` + `KEY_SANDBOX_STORE: sandbox_store` edits to
main.gd were reverted because Codex's SandboxPersistenceService injection
already covers the wiring cleanly. Adding the unused key + port would
have been dead code.

## Files Touched (mine, now in HEAD via Codex's commits)
- `src/domain/gameplay/sandbox_state.gd` (created; later extended by
  Codex into `sandbox_snapshot.gd` then consolidated back to
  `sandbox_state.gd`)
- `src/adapters/outbound/filesystem_sandbox_store.gd` (created;
  Codex tightened it to a 31-line wrapper)
- `tests/domain/test_sandbox_state.gd` (created; Codex tightened
  the assertions to match the final API)

## Files Touched (Codex's, not mine)
- `src/adapters/outbound/filesystem_session_progress_store.gd`
- `src/application/sandbox_persistence_service.gd`
- `src/adapters/inbound/main.gd` (Phase 1/Phase 2 + screenshot
  capture refactor)
- `src/adapters/inbound/scenes/play/play_shell.gd` + `.tscn`
- `src/adapters/inbound/gameplay/gameplay_runtime.gd` (SandboxState
  get/restore)
- `tests/adapters/outbound/test_filesystem_session_progress_store.gd`
- `.ai/research-compendium/RESEARCH_VS-026_*.md` (deep enrichment)
- `.ai/reviews/VS-026-codex-review.json`

## Backlog Update
- `VS-026` moved to `in_review`. Evidence block updated to include
  my SandboxState + tests + handoff alongside Codex's
  implementation files.

## Validation Performed
- `godot4 --headless --path . --script
  tests/domain/test_sandbox_state.gd` → `[test_sandbox_state] OK`
  (8 checks).
- `godot4 --check-only --headless --script
  res://src/domain/gameplay/sandbox_state.gd` and
  `res://src/adapters/outbound/filesystem_sandbox_store.gd` →
  compile clean.
- Full smoke boot (`godot4 --headless --path .`): session starts,
  player spawns, Codex's auto-save / resume path is on the runtime.
  No errors related to my files.

## Open Risks / Notes
- Both `FilesystemSandboxStore` (mine) and
  `FilesystemSessionProgressStore` (Codex's) exist as files. They
  cover overlapping ground: the sandbox store wraps the snapshot
  type directly; the session progress store is the formal
  SessionProgressStorePort adapter. Codex's wider use of the port +
  service is the right long-term shape; the sandbox store can stay
  as a thinner convenience wrapper if gameplay ever wants raw
  snapshot I/O without going through the service. No collision
  today since the FilesystemSandboxStore class isn't injected into
  the port registry.
- Codex's deep-enrichment research at
  `.ai/research-compendium/RESEARCH_VS-026_DEEP_ENRICHMENT.md`
  documents the design alternatives considered.
- VS-026 acceptance criteria status:
  1. **World state, player position, inventory, placed blocks and
     progression save locally without a blocking modal** — DONE
     via auto-save in `_ensure_session_music` flow / end_session
     in play_shell.gd.
  2. **Relaunch resumes the latest valid local sandbox state by
     default** — DONE via SandboxState.load_from_disk in
     start_session integration.
  3. **An explicit main-menu New Game action clears only the selected
     local sandbox save after confirmation** — DONE via NewGameButton
     in play_shell.tscn + clear_disk on the sandbox store.
  4. **Corrupt or incomplete local save safely falls back to a new
     playable sandbox** — DONE via SandboxState.load_from_disk's
     empty-state fallback (corrupt JSON → empty SandboxState → fresh
     playable sandbox).

## Review Focus Suggestions
- Whether the dual-store approach (FilesystemSandboxStore +
  FilesystemSessionProgressStore) should be consolidated to one
  service in a follow-up.
- Whether the auto-save trigger points in gameplay_runtime + play_shell
  cover all kid-initiated quit paths (alt-F4, OS shutdown, etc.).
- Whether the New Game confirmation should also clear the session
  progress (achievements, unlocks) or only the world state.
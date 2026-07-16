# Thin Slice — Adventure, Playable A→Z on Mac

**Date:** 2026-07-19 · **Revised:** 2026-07-19 (post-adversarial-review + implementation)
**Branch base:** `main` @ `bc3586b`
**Work branch:** `fix/adventure-thin-slice-combat-first-run` @ `9f1967c`
**Scope (locked with user):** Adventure world only · real landing→click entry (no dev flags) · **win by defeating enemies**

---

## Revision note (READ FIRST)

The original plan's thesis was **"this is a one-line JSON change."** Adversarial
review + independent code verification found that was **wrong**: the JSON change
was *necessary but not sufficient*. A release BLOCKER sat directly on the win
loop, and the original success criteria (`--smoke` autoplay) could pass while
the real kid path was broken.

**BLOCKER (found + fixed): first-run kids had combat OFF on the real click path.**

- The played session reads parental policy via `_resolve_policy_for_session`
  (`play_shell.gd:463`). Post-boot, `_policy_store` is the **EncryptedParentalPolicyStore**
  (`main.gd:418`, swapped into PlayShell at phase-2 `main.gd:501`→`_wire_shell_dependencies`
  `:531`→`setup_combat_governance` `:909`). The InMemory stub is *gone* by click time.
- For a brand-new kid (no vault file), `EncryptedParentalPolicyStore.load_policy`
  returns **`deny_all()`** — combat OFF — not `null`. This is the *correct*
  fail-closed behavior for a tampered vault, locked in by
  `encrypted_parental_policy_store_adapter_contract_test.gd` and
  `test_encrypted_parental_policy_store_deny_all.gd` (MUST-9).
- But `_resolve_policy_for_session` only fell back to `default_for_first_run()`
  (combat ON, wave_cap 5) when the load returned **`null`**. Absence and tamper
  both surfaced as `deny_all`, so the friendly first-run branch was **dead code**
  against the real store.
- Net: `_is_combat_allowed()` false → `_spawn_starter_enemies` prints
  `"combat disabled by parental policy — no enemies spawned"` (`gameplay_runtime.gd:685`)
  → **zero enemies → score stuck at 0 → `score>=15` never fires → no win.**
- **This Mac has no `choyce_vault` dir**, so the dev's own A→Z run hits exactly
  this. Not hypothetical.
- **`--smoke` masked it**: autoplay uses `_permissive_autoplay_policy()`
  (combat on), bypassing the vault. Smoke green ↔ real kid path broken. The
  original Phase-1 automated criterion was a false signal.

**Verified CORRECT in the original plan** (independently re-checked, all hold):
`_score += 5` per defeat (`gameplay_runtime.gd:810`) · `"score": _score` live in
the goal ctx every frame (`:1429`, evaluated `:1380`) · `score` whitelisted in
the DSL (`win_condition_interpreter.gd:36`) · win_condition flows JSON →
`TemplateLoader.build_goal_from_template` → `PlayShell.setup_goal` → `_goal`
(`play_shell.gd:410`, injected `main.gd:921`) · win latches before any respawn
via `_outcome_emitted` (`gameplay_runtime.gd:1368`). So the score-based win is
genuinely reachable **once combat is on**.

**Correction to the original Phase-2 "vault staleness" note:** the polarity was
backwards. The trap is not "a prior test persisted combat=false" — it's that a
**fresh** profile is combat=false *by default* against the encrypted store.

---

## Goal

A kid on a Mac launches the game, lands on the menu, clicks the Adventure world
card, plays, **defeats the enemies, sees a win celebration, and returns to the
menu** — no console flags, no Create-shell detour, no manual setup. One world,
one complete loop, near-final feel.

## Status: Phase 1 DONE

Implemented + committed on `fix/adventure-thin-slice-combat-first-run` @ `9f1967c`,
TDD, full contract suite green (78 contracts / 1029 checks / 0 failed;
application 18/302; family-session + COPPA suites PASS; domain-isolation PASS).

---

## Phase 1 — Make Adventure winnable by defeating enemies (DONE)

**Intent:** Turn "walk around" into "play a game with a win" on the *real* path.

### 1a — Data: the winnable goal ✅
`data/templates/adventure.json` — `default_goal`:

```jsonc
// FROM: "target": 3,  "label_pl": "Zbierz 3 klucze",   "icon_id": "icon_key",   "win_condition": "inventory.key>=3"
// TO:   "target": 15, "label_pl": "Pokonaj 3 potwory", "icon_id": "icon_sword", "win_condition": "score>=15"
```
The played world grants no `key`, so the shipped goal was unreachable. Each
enemy defeat adds 5 to `score` → 3 defeats = 15 = win.

### 1b — Fix: first-run combat on the real click path ✅ (the BLOCKER)
Root-cause fix at the one decision point, preserving the deny-all-on-tamper
security property:

- **`ParentalPolicyStorePort.has_policy(parent_id)`** — new port method + both
  adapters. Distinguishes "brand-new profile, nothing stored" from
  "present-but-unreadable." Encrypted impl = file-exists (tamper still counts as
  present); InMemory = key present.
- **`ParentalControlPolicy.resolve_for_session(has_stored, stored)`** — new pure
  domain decision: nothing stored → `default_for_first_run()` (combat on);
  stored+valid → honor it; stored+broken → `deny_all()` (fail closed, *not*
  first-run).
- **`_resolve_policy_for_session`** now calls `has_policy` + `resolve_for_session`
  instead of the dead `stored == null` check.

### Risk / verified during impl
- HUD **progress bar** (`GameGoal.progress_ratio`, `game_goal.gd:64`) for
  `kind:collect` reads `inventory.<name>`, NOT `score`. The *win* fires on
  `score>=15`; the *bar* may sit at 0 until win. **Acceptance is the win firing**
  — bar polish is Phase 3. Not a blocker.
- Changing the encrypted store's fail-closed behavior was explicitly avoided —
  it would break 8 other `load_policy` callers (audio, language, data-lifecycle)
  and the deny-all security tests. The fix is localized to policy *resolution*.

### Success criteria
- [x] Automated: `godot --headless --editor --quit` parse-clean (touched play_shell + domain + adapters).
- [x] Automated: full contract suite green — 78 contracts / 1029 checks / 0 failed.
- [x] Automated (the BLOCKER guard): `play_session_policy_resolution_contract_test.gd`
      proves a fresh kid on a live `EncryptedParentalPolicyStore` resolves to
      **combat ENABLED**. Verified this test FAILS under the old `stored==null`
      logic before the fix landed.
- [x] Regression: application (18/302), family-session, COPPA data-lifecycle, domain-isolation all PASS.
- [ ] **Manual (Phase 2 — the real acceptance):** launch → land → click Adventure
      on a clean profile → kill 3 enemies → celebration → menu.

### Files (Phase 1 — landed)
| File | Change |
|------|--------|
| `data/templates/adventure.json` | Modify — `default_goal` → `score>=15` |
| `src/ports/outbound/parental_policy_store_port.gd` | Modify — `has_policy()` |
| `src/adapters/outbound/encrypted_parental_policy_store.gd` | Modify — `has_policy()` (file-exists) |
| `src/adapters/outbound/in_memory_parental_policy_store.gd` | Modify — `has_policy()` |
| `src/domain/identity_safety/parental_control_policy.gd` | Modify — `resolve_for_session()` |
| `src/adapters/inbound/scenes/play/play_shell.gd` | Modify — resolution uses has_policy + resolve_for_session |
| `tests/contracts/*` (3 new + runner) | Add — has_policy, resolve_for_session, integration BLOCKER guard |

---

## Phase 2 — Manual clean-profile A→Z (the real acceptance)

**Intent:** Automated smoke uses autoplay (permissive policy) and **cannot**
prove the click path — it structurally bypasses the very code the BLOCKER lived
in. Only a human, clean-profile, no-env-flags run proves the slice.

### Work
1. **Clean profile.** Wipe `~/Library/Application Support/Godot/app_userdata/Choyce Engine/choyce_vault/`
   (or use a fresh `CHOYCE_PROFILE_ID`). Confirm no vault file exists.
2. **Launch with NO env flags** (`godot --path .` or `scripts/dev/run.sh`,
   no `CHOYCE_AUTOPLAY`). Click the Adventure card. **Enemies must spawn** —
   this is the fix's payoff. If the log shows
   `"combat disabled by parental policy"`, the fix regressed.
3. **Kill 3 enemies.** Confirm celebration overlay ("Wygrana!") fires at score 15.
4. **Wave respawn vs win latch:** `wave_cap=5` respawns a wave once the field is
   clear, but the win latches via `_outcome_emitted` the frame score hits 15
   (`gameplay_runtime.gd:1368`). Verify the celebration reads cleanly before any
   respawn muddies it. (Code confirms latch fires first; verify visually.)
5. **Return-to-menu.** Celebration close → `_on_session_ended` frees the runtime,
   re-shows Layout, releases mouse. Confirm no orphaned `GameplayRuntime` at
   `/root`, mouse usable, second play of the same card works.

### Success criteria
- [ ] Clean profile, NO env flags: menu → Adventure → **enemies spawn** → 3 kills → win → menu. Full loop.
- [ ] Log shows combat_session_started + 3 defeats + a win outcome (NOT "combat disabled").
- [ ] No orphaned Node3D at `/root` after return; mouse VISIBLE on menu.
- [ ] Second play of the same card works (no stale-state soft-lock).

### Files
| File | Change |
|------|--------|
| `docs/release/runbook-local-only.md` | Modify — clean-profile A→Z step + vault-reset note |

---

## Phase 3 — Feel pass (optional polish, in impact order)

Each independent; no new systems.
1. **Score-aware goal HUD bar.** `GameGoal.progress_ratio` (`game_goal.gd:64`)
   reads `inventory` for `kind:collect`; add a 3-line branch reading
   `ctx["score"]/target` when the win is score-based so the bar tracks 0→15.
   `ponytail:` a branch, not a new goal kind.
2. **Win/defeat copy + audio.** Confirm celebration plays a win sting; HUD label
   "Pokonaj 3 potwory" counts down. Reuse `_audio_bus.emit_sfx`.
3. **One NPC line that references the goal.** Data-only in `npc_dialogue.json` —
   e.g. "Pokonaj potwory!" so the world explains itself.
   *(Note: `_spawn_one_npc` logs a benign `!is_inside_tree()` warning at
   `gameplay_runtime.gd:562` — pre-existing, cosmetic, off the win loop. Fix
   opportunistically if touching NPC code.)*
4. **Lose path is soft.** lives:3 / 300s → session-end panel with "Spróbuj
   jeszcze raz." Already wired (`play_shell.gd:453`); just verify.

### Files
| File | Change |
|------|--------|
| `src/domain/world_authoring/game_goal.gd` | Modify — score-aware `progress_ratio` (optional) |
| `data/templates/npc_dialogue.json` | Modify — one goal-referencing line (optional) |

---

## Phase 4 — Capture the slice (deliverable)

- Record a clean 60–90s Mac playthrough: launch → land → Adventure → defeat 3
  monsters → win → menu. No dev console visible.
- Runbook records exact launch command (Godot 4.6.1, Mac).

### Success criteria
- [ ] Single unbroken recording of the full A→Z, no dev flags.
- [ ] Runbook "Launch procedure" updated to the actual clicked path.

---

## Testing strategy (overall)

- **Fast gate:** `godot --headless --editor --quit` (parse) then the contract
  suite (`tests/contracts/run_contract_tests.gd`) — includes the new BLOCKER guard.
- **`--smoke` is a boot/regression probe only.** It uses autoplay + a permissive
  policy and **cannot** exercise the first-run vault path. Do not treat a green
  smoke as proof the kid click path wins. The manual Phase-2 run is the real gate.
- **BLOCKER regression guard:** `play_session_policy_resolution_contract_test.gd`
  fails if first-run combat ever regresses to off.

## Rollback

Phase-1b (the fix) is additive (new port method + new static + resolution
rewire) — revert the six source files + three tests. Phase-1a is a single-file
JSON revert. No schema, no migration, no persisted-state change. Worst case the
goal reverts to unreachable-but-safe `inventory.key>=3` and combat reverts to
off-on-fresh — exactly today's (broken) state.

## Out of scope (deferred — do NOT build for the slice)

Other 4 templates as winnable · AI/Ollama creation · voice input · parent PIN ·
COPPA export UI · rule-engine `SPAWN_ITEM`/`UNLOCK_AREA` · typed hit/hurt Area3D
refactor · loot-table refactor · multiplayer/cloud/publishing · missing
`forest.json` · score-aware HUD bar (Phase 3, not a blocker).

## Open flags / uncertainty

- **HUD bar vs win decoupling** (Phase 1 risk, accepted): win fires on
  `score>=15`; the collect-kind bar reads inventory. Phase 3 fixes the bar. Not a blocker.
- **Manual Phase-2 is unproven in-session** — no live clicked run yet. The fix is
  proven at the unit/integration layer (fresh vault → combat on) but the
  full visual A→Z click loop still needs a human pass.
- **Wave respawn vs win latch** (Phase 2): code confirms the latch fires the
  frame score hits 15, before respawn; verify visually.

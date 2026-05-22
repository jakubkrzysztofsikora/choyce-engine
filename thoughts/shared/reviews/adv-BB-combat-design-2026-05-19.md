# Adversary BB — Combat Design Audit (2026-05-19)

Target: 7yo. Verdict: **Mediocre combo, weak feedback loop, no boss telegraphs, no aim-assist.** Skeletal anims look nice. Mechanically thin underneath.

## Findings (ranked, P0 → P3)

### P0-1 — Combo is a cosmetic-only cycle. No phase identity.
`player_controller.gd:438` increments `_punch_phase` monotonically forever. No idle-reset (0.6s rule absent). All four phases call `_perform_attack` with **uniform** `_equipped_weapon_damage`, **uniform** `ATTACK_COOLDOWN=0.4`, **uniform** `ATTACK_RANGE=1.8`, **uniform** `ATTACK_ARC_RADIANS=1.4`. Kick = jab mechanically. Punch reaches as far as a kick. **No light/heavy distinction.**

Patch:
- `const PUNCH_RESET_GAP := 0.6` — in `_perform_attack`, if `Time.get_ticks_msec() - _last_swing_ms > 600`, reset `_punch_phase = 0`.
- Phase profile table:
  ```
  PHASE_PROFILES = [
    {dmg_mult: 1.0, cd: 0.32, range: 1.6, arc: 1.2},  # jab — fast, short
    {dmg_mult: 1.1, cd: 0.36, range: 1.7, arc: 1.3},  # cross
    {dmg_mult: 1.6, cd: 0.55, range: 2.4, arc: 1.5},  # kick — heavy, long
    {dmg_mult: 1.8, cd: 0.70, range: 2.5, arc: 1.6},  # finisher kick — payoff
  ]
  ```
- Apply `damage = int(_equipped_weapon_damage * profile.dmg_mult)`, plumb range/arc into the hit-detect loop, set `_attack_cooldown = profile.cd`.
- Phase 3 finisher: 1.5× hit-stop, 1.5× screen-shake, bigger `_spawn_damage_number(is_boss=true)` flag for visual oomph.

### P0-2 — Enemies don't fight back. They trundle and tank.
`enemy_controller.gd:222` `_state_hurt` is pure 0.2s pause — **no stagger animation, no flinch, no parry, no dodge**. Player can hold LMB and pulverise a slime that never threatens beyond contact bonk. Bouncer has no telegraphed jump-attack. `BIG_SLIME` boss has zero wind-up — instant contact damage at 0.6m.

Patch:
- Add `_telegraph_remaining: float` on `EnemyController`. Bouncer + BIG_SLIME enter a `WINDUP` micro-state 0.8s (mob) / 1.2s (boss) before contact damage. Visual: scale Y up to 1.3× + tint to bright red for the windup window. Kid gets a clear "dodge now" cue.
- During `HURT`, blend a knockback scale-squash (already partial via `tint` flash). Extend stagger to 0.35s on phase-3 finisher hits.
- Optional parry: hold-RMB → 0.3s parry window; on enemy contact during parry, deflect + 1.0s enemy stagger. Adv BB recommends **deferring parry** until base combo lands — 7yo first needs the rhythm.

### P0-3 — No lock-on / aim assist. 7yo mouselook misery.
`_perform_attack` uses a hard front-cone. Kid pans camera roughly toward slime, swings, misses by 20°, frustration. No soft-aim, no snap, no auto-face.

Patch in `_perform_attack` BEFORE the hit-sweep:
```
var best: EnemyController = _nearest_enemy_in_cone(forward, ATTACK_RANGE * 1.4, ATTACK_ARC_RADIANS * 1.5)
if best != null:
    var to_e := (best.global_position - global_position); to_e.y = 0
    var assist_yaw := forward.signed_angle_to(to_e.normalized(), Vector3.UP)
    if absf(assist_yaw) < 0.5:  # ~28°
        rotate_y(assist_yaw * 0.6)  # 60% of the way — visible but not robotic
```
Soft-snap, not magnet. Preserves agency. Saves the 7yo from camera-fight on every swing.

### P1-4 — Weapon-vs-fist anim doesn't branch.
`_weapon_tiers` ladders fist → stick → iron sword → epic sword (`gameplay_runtime.gd:36`). All four use `ATTACK_ANIMS = ["attack-melee-right", "attack-melee-left", "attack-kick-right", "attack-kick-left"]`. Kid earns an "Epicki miecz" and… still throws Muay-Thai kicks. **Progression has no visual payoff at the swing level.**

Patch:
- `equip_weapon_damage(damage)` → also accept `weapon_kind: String` ("fist"/"stick"/"sword"). Cache on player.
- `ATTACK_ANIMS_BY_KIND = { "fist": [melee-R, melee-L, kick-R, kick-L], "sword": ["sword-slash-down", "sword-slash-up", "sword-thrust", "sword-spin"] }`. Kenney character pack ships sword variants — `_anim_player.has_animation()` fallback already covers the gap.
- Sword tier: cut kick phases, add wider arc (2.2 rad) for slash sweeps. Reads as "real weapon".

### P1-5 — Damage values uniform. No crit, no variance.
`_perform_attack` deals exactly `_equipped_weapon_damage` every swing. Crits absent. Number-feedback is monotone "-4 -4 -4 -4 -4". 7yo reward loop needs **occasional golden number** (Hades, Vampire Survivors).

Patch:
- 15% chance: `damage = int(base * 1.75)`, pass `is_crit=true` through `damaged_with_amount` → `_spawn_damage_number` renders in gold/larger font, plays distinct SFX.
- Phase-3 finisher: auto-crit (combo payoff).

### P1-6 — Reward chain is muted on regular kills.
`_on_enemy_defeated` does shake + hit-stop + sparkle + XP. Good. **But:** no kill-confirm sound distinct from `"collect"` SFX. Level-up uses same `"collect"` SFX (`gameplay_runtime.gd:683`). Kid hears identical "tink" for picking up grass blade and reaching level 5.

Patch:
- Add audio bus events: `"enemy_defeated"`, `"enemy_defeated_boss"`, `"level_up"`. Route through `AudioBank`. Level-up = rising 3-note arpeggio. Boss-kill = orchestral hit.
- Damage numbers already exist (`_spawn_damage_number`) — extend with screen-position "+1 LVL!" pop when level changes, separate from sparkle burst.

### P1-7 — No "easy mode" HP/damage scaling.
`enemy_definition.gd` HP/contact_damage are static per archetype. `wave_director_service.gd` `hp_mult = 1 + sqrt(N) * 0.25` ramps regardless of kid skill. 7yo with bad rhythm hits a wall at wave 4-5.

Patch:
- Extend `ParentalControlPolicy` with `combat_difficulty: enum {EASY, NORMAL}` (default EASY).
- `EASY`: enemy `hp_mult *= 0.6`, `contact_damage *= 0.5`. Apply in `_spawn_one` after `setup()`:
  ```
  if policy.combat_difficulty == EASY:
      enemy.health.max_hp = int(enemy.health.max_hp * 0.6)
      enemy.definition.contact_damage = int(enemy.definition.contact_damage * 0.5)
  ```
- Parent zone toggle. Default EASY honours CLAUDE.md "consent → deny".

### P2-8 — `_check_aggro` runs every physics tick on every enemy, scans `_player_ref` distance. O(N) with no early-out for off-screen mobs. Not a perf P0 at <20 enemies but wave-cap can hit 7+.
Patch: skip aggro check when `_state == DEFEAT` already done, also skip when distance > `aggro_radius * 2` and frame_counter % 4 != 0 (poll every 4 frames at long range).

### P2-9 — `_punch_phase` integer overflow theoretical at int64-max swings. Unreachable in practice (kid would need 5e18 swings) but `% ATTACK_ANIMS.size()` masks it. Note only.

### P2-10 — `XP per kill` not visible in code reviewed. `_xp_service.xp_for_kill(enemy_id)` lives in `XpProgressionService` (not in this review's scope). Verify the kill→XP→level cadence: a wave of 4-5 slimes should net ~1 level for the 7yo dopamine drip. If kills give <0.25 levels each, snappiness suffers. **Audit `XpProgressionService.xp_for_kill` separately.**

### P3-11 — Hit-stop duration (`_apply_hit_stop`) fires only on enemy DEFEAT, not on regular hits. Compare: Sekiro hit-stops every parry. Souls every R1. Add 0.03s micro-stop on every connecting swing — `_on_enemy_damaged` is the hook point.

### P3-12 — `attack_arc_radians=1.4` (~80°) is wide-forgiving (good for 7yo) but combined with no lock-on means kid still misses small targets at edge of arc. Pair with P0-3 aim-assist for full benefit.

## Patch Priority for Implementation

1. **P0-1 phase profiles** — biggest combat-feel win, isolated edits inside `player_controller.gd::_perform_attack` + new `PHASE_PROFILES` const.
2. **P0-3 soft aim-assist** — biggest playability win for 7yo, isolated to `_perform_attack` prelude.
3. **P0-2 enemy windup/stagger** — adds threat & reaction window; touches `enemy_controller.gd` state machine.
4. **P1-7 easy mode** — single policy field, big difficulty win.
5. **P1-4 weapon anim branch** — visual payoff for gear loop.
6. **P1-5 crits** + **P1-6 audio cues** — reward dopamine.

## Files Touched by Recommended Patches

- `/Users/jakubsikora/Repos/choyce-engine/src/adapters/inbound/gameplay/player_controller.gd` — phase profiles, aim-assist, weapon anim branch
- `/Users/jakubsikora/Repos/choyce-engine/src/adapters/inbound/gameplay/enemy_controller.gd` — WINDUP state, longer stagger
- `/Users/jakubsikora/Repos/choyce-engine/src/adapters/inbound/gameplay/gameplay_runtime.gd` — crit damage numbers, distinct SFX events, easy-mode application
- `/Users/jakubsikora/Repos/choyce-engine/src/domain/safety/parental_control_policy.gd` — `combat_difficulty` field (not read this pass; verify)
- `/Users/jakubsikora/Repos/choyce-engine/src/application/combat_service.gd` — optional: accept `crit_multiplier` arg

Report by Adv BB, ready for synthesis.

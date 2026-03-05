# TASK-024 Review Findings (Mistral - Cross-Review)

## Summary
**Status: APPROVED WITH FINDINGS**

TASK-024 implements one-click playtest launch and local solo/co-op baselines. Implementation is architecturally sound with solid framework isolation and DI patterns. Three minor findings require clarification/correction before merge.

---

## Acceptance Criteria Verification

### ✅ Criterion 1: Playtest launches from current scene in one action
- **Verified**: CreateShell.GoPlay button → `_launch_playtest(false)` → navigation to Play shell
- **Design**: Clean single action as required

### ✅ Criterion 2: Session runtime supports local solo/co-op baselines
- **Verified**: PlayShell provides explicit solo/coop buttons
- **Service Logic**: RunPlaytestService correctly assigns SessionMode.PLAY (1 player) and SessionMode.CO_OP (2+ players)
- **Coverage**: Contract test validates both paths

---

## Architecture Review

### ✅ Framework Isolation
- Adapters (CreateShell, PlayShell) remain framework-agnostic
- No Godot concerns leak into service layer
- Domain types (PlayerProfile, Session, World) properly used

### ✅ Dependency Injection
- Both shells use `setup()` method pattern
- Null checks prevent crashes on missing dependencies
- Signal-based propagation (world_context_changed) decouples shells

### ✅ World Context Management
- Bootstrap logic in `_ensure_world_context()` intelligently creates default world if missing
- Signal properly connects CreateShell → PlayShell context propagation
- PlayShell initialized with active world on wiring (line 73, main.gd)

### ✅ Service Design
- RunPlaytestService validates playable state (rules OR nodes present) before session creation
- Guest profile ID generation uses deterministic suffix (`_local_guest`) to prevent collisions
- Clock port correctly used for timestamps

---

## Findings

### Finding 1: Polish Localization Text Errors (LOW - Text Correction)
**Location**: `data/localization/ui_pl.json`

**Issue**: Missing Polish diacriticals in UI string
```json
"ui.play.info": "Wybierz swiat i uruchom sesje."
```

**Should be**:
```json
"ui.play.info": "Wybierz świat i uruchom sesję."
```

**Impact**: Polish text is grammatically incorrect and appears unprofessional to Polish-speaking users.

---

### Finding 2: Fallback Text Mismatch (LOW - Consistency)
**Location**: `src/adapters/inbound/scenes/play/play_shell.gd` line 110

**Issue**: Fallback text doesn't match localization file
```gdscript
"ui.play.start_coop": "Start co-op lokalny"  # In PlayShell
```

**Actual in ui_pl.json**:
```json
"ui.play.start_coop": "Start lokalny co-op"   # Different word order
```

**Impact**: If translation service fails, UI will show mismatched text. Minor but breaks consistency principle.

**Recommendation**: Align fallback to match localization file: `"Start lokalny co-op"`

---

### Finding 3: Co-op Contract Test Design Question (MEDIUM - Design Clarity)
**Location**: `tests/contracts/run_playtest_service_contract_test.gd` line 70

**Issue**: Co-op test mixes KID + PARENT role
```gdscript
var kid := PlayerProfile.new("kid-1", PlayerProfile.Role.KID)
var parent := PlayerProfile.new("parent-1", PlayerProfile.Role.PARENT)
var coop_session := service.execute("world-playtest", [kid, parent])
```

**Question**: Is PARENT expected to participate in local co-op playtests? Or should both players be KID role?

**Recommendation**:
- If PARENT is intended: Document this design decision in service docstring
- If not intended: Fix test to use two KID profiles instead
- Current implementation doesn't block it (no role checking), so this is a clarification needed, not a blocker

---

## Good Design Observations

1. **Bootstrap Pattern**: `_ensure_world_context()` intelligently creates default "starter_canvas" world if missing — great UX
2. **Graceful Degradation**: Silent null returns instead of exceptions — allows partial failures
3. **Playtestability**: World validation (requires rules OR nodes) prevents launching empty worlds
4. **Signal Architecture**: world_context_changed signal properly decouples shells from direct knowledge of each other

---

## Contract Test Coverage
- ✅ Solo playtest (1 player) → SessionMode.PLAY
- ✅ Co-op playtest (2+ players) → SessionMode.CO_OP
- ✅ Missing world → null return
- ✅ Empty world (no rules/nodes) → null return
- **Suggestion**: Consider test for 3+ player co-op to verify multi-player baseline

---

## Recommendation

**APPROVE** — Merge after addressing Findings 1 & 2 (text corrections). Finding 3 is a design question that doesn't block functionality but should be clarified in service docstring or test comment before final merge.

**Path Forward**:
1. Fix Polish diacriticals in ui_pl.json (Finding 1)
2. Align PlayShell fallback text to match localization (Finding 2)
3. Add clarifying comment in contract test about role mix expectation (Finding 3)
4. Merge to unblock TASK-025 & TASK-026

---

**Reviewed by**: Mistral (Architecture & Systems)
**Date**: 2026-03-02
**Cross-review requested by**: codex (pending)

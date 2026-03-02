# UI/UX Requirements

## 1) UX principles for ages 6–8 + parent co-use
- **Play-first, text-light**: icons, animations, spoken guidance.
- **Confidence loops**: immediate positive feedback after each creation action.
- **One concept per screen**: reduce cognitive load.
- **Co-pilot not autopilot**: AI suggests, child chooses.
- **Dual-track complexity**: kid mode simple; parent mode deep.

---

## 2) Primary user journeys

## 2.1 Child quick-start (under 3 minutes)
1. Pick a template card (e.g., “Pet Tycoon”).
2. Choose theme palette.
3. Place first object with guided sparkle cue.
4. Press Play and complete first tiny quest.

## 2.2 Parent-child co-creation
1. Child builds base world with blocks.
2. Parent opens Advanced Drawer.
3. AI explains logic in two layers: “kid explanation” and “parent details.”
4. Parent approves patch; child sees fun visual result.

## 2.3 Gameplay help
1. Child asks helper NPC by voice/text.
2. NPC gives hint tier 1 (nudge), then tier 2, then tier 3 if asked.
3. Reward for solving without full answer.

---

## 3) Information architecture
- Home
  - Create
  - Play
  - Family Library
  - Parent Zone (locked)
- Create
  - Templates
  - Build Canvas
  - Logic Blocks
  - AI Helper
- Play
  - Worlds
  - Quests
  - Progress
- Parent Zone
  - Safety controls
  - Time limits
  - AI policy
  - Publish approvals

---

## 4) Interaction requirements
- UX-001: Minimum touch target 44px equivalent.
- UX-002: Color + icon + shape (not color-only signals).
- UX-003: Always-available undo and “go back to safe save.”
- UX-004: Tooltips can be spoken aloud.
- UX-005: Loading states use educational micro-prompts (“Did you know…”).
- UX-006: No dark patterns, no manipulative countdowns.

---

## 5) Kid mode requirements
- UX-KID-001: Reading level around early elementary; optional full voice narration.
- UX-KID-002: Bounded choices (3–5 options per step).
- UX-KID-003: Friendly mascot guide with consistent persona.
- UX-KID-004: Celebration animations under 2 seconds to keep flow.

---

## 6) Parent mode requirements
- UX-PARENT-001: Advanced script editor with linting and AI explain/patch preview.
- UX-PARENT-002: Diff view before AI or script changes are applied.
- UX-PARENT-003: Safety console with moderation logs and quick policy presets.
- UX-PARENT-004: Co-learning suggestions mapped to skills (logic, sequencing, creativity).

---

## 7) AI interaction UX
- UX-AI-001: AI responses should include “why” in simple language.
- UX-AI-002: Every AI action card has: Preview, Apply, Undo.
- UX-AI-003: Safety refusal must be polite and offer safe alternatives.
- UX-AI-004: Transparency badge when content is AI-generated.

---

## 8) Accessibility requirements
- UX-A11Y-001: WCAG 2.2 AA baseline for contrast and navigation.
- UX-A11Y-002: Dyslexia-friendly font option.
- UX-A11Y-003: Captions for all spoken AI guidance.
- UX-A11Y-004: Motor-friendly simplified control preset.

---

## 9) Visual design system requirements
- Rounded, toy-like visual language.
- High-contrast pastel palette with safe red/green alternatives.
- Modular card-based layouts.
- Consistent iconography for action verbs (Build, Test, Share, Ask AI).

---

## 10) Research-backed design notes to incorporate
- Child creative platforms succeed when remixing and immediate feedback are central.
- Block-based coding lowers barrier and supports transition to text scripting.
- Family trust increases with transparent controls and explainable moderation.
- AI assistants are best framed as collaborative guides, not authoritative judges.

---

## 11) UX validation requirements
- Monthly playtests with child-parent pairs (6–8 age segment).
- Measure:
  - time-to-first-fun
  - task completion without adult rescue
  - parent trust in AI suggestions
  - frustration signals (rage taps, abandonment)
- Required benchmark for MVP:
  - 80% of children complete first playable loop in <=15 minutes.

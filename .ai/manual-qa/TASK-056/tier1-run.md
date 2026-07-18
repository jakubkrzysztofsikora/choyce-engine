# TASK-056 Tier-1 Run

- Date: 2026-07-18
- Tester: claude (AI Architecture Agent — static code analysis of `main.gd`, `create_shell.gd`, `launcher_overlay.gd`)
- Hardware tier: Tier-1
- Device spec: N/A (static analysis — live evidence deferred to TASK-063 AI vision runner)
- OS version: macOS 15.0.0
- Build/commit: 9be15cbd2eebb6263033f1b5240eb06de2024374
- Start time (UTC): 2026-07-18T02:00:00Z
- End time (UTC): 2026-07-18T02:30:00Z

## Localization Results

<a id="l10n-1"></a>
### L10N-1 Primary kid-flow localization
- Expected: kid mode labels and dialogs use Polish by default.
- Observed: the primary Create shell labels remain localized through `_t()`, and `PlayerProfile.language` still defaults to `pl-PL`.
- Gap: helper surfaces in `create_shell.gd` still bypass the localization policy, especially `_ensure_back_button()`, `_ensure_quick_build_row()`, `_update_preview_grid()`, `_build_kid_voice_cta()`, and `_on_kid_voice_cta_pressed()`.
- Pass/Fail: **PARTIAL PASS** (primary labels pass; helper surfaces still need localization cleanup — F-056-01)

<a id="l10n-2"></a>
### L10N-2 Parent flows
- Expected: parent shell defaults to Polish unless overridden.
- Observed: the same `PolishLocalizationPolicy` is wired through the parent flow and no English fallback surfaced in the reviewed path.
- Pass/Fail: **PASS**

<a id="l10n-3"></a>
### L10N-3 Parent language override behavior
- Expected: override requires parent control and does not silently change kid defaults.
- Observed: `SetParentalControlsService` still gates policy changes by role, and no kid-language override path was found in the parent controls panel.
- Pass/Fail: **PASS**

<a id="l10n-4"></a>
### L10N-4 AI helper responses
- Expected: AI helper responses in text and voice default to natural, age-appropriate Polish.
- Observed: `voice_assistant_overlay.gd:128-170,233-246` keeps the moderation feedback and block cue in Polish, and `create_shell.gd:1407-1408,1511-1526` speaks Polish fallback/confirmation feedback.
- Pass/Fail: **PASS**

<a id="l10n-5"></a>
### L10N-5 Voice personas
- Expected: voice personas and narration use Polish speech as the primary experience.
- Observed: `create_shell.gd:1482-1508` routes the kid CTA into Polish helper speech, and `launcher_overlay.gd:262-281` keeps the cinematic lines captioned while the Polish voice lines play.
- Pass/Fail: **PASS**

## Accessibility Results

<a id="a11y-1"></a>
### A11Y-1 Captions
- Expected: spoken AI guidance has captions.
- Observed: `main.gd:1253-1256` wires the captions toggle into `AccessibilityPolicyPort`, and `launcher_overlay.gd:262-281` keeps the spoken cinematic lines captioned on screen.
- Pass/Fail: **PASS**

<a id="a11y-2"></a>
### A11Y-2 Contrast
- Expected: UI remains legible and compliant in core flows.
- Observed: the shell uses high-contrast StyleBoxFlat button palettes in the quick-build row and kid CTA. Formal WCAG math still needs a live screenshot pass.
- Pass/Fail: **CONDITIONAL PASS**

<a id="a11y-3"></a>
### A11Y-3 Dyslexia font
- Expected: dyslexia-friendly font mode is available and stable.
- Observed: `main.gd:1254-1256` wires the dyslexia toggle directly into the accessibility policy.
- Pass/Fail: **PASS**

<a id="a11y-4"></a>
### A11Y-4 Motor preset
- Expected: simplified motor controls are usable in core flows.
- Observed: `main.gd:1254-1256` wires the motor toggle into `set_motor_scale(1.25)` and the target sizes stay large enough in the reviewed shell paths.
- Pass/Fail: **PASS**

## Coverage notes

- No explicit reduce-motion requirement or toggle was found in `docs/requirements/ui-ux-requirements.md` or the current shell code. That was checked as part of the accessibility review, but it is not backed by a canonical requirement ID.

## Findings

<a id="f-056-01"></a>
- ID: F-056-01
  - Severity: HIGH
  - Repro steps: Open Create mode and inspect the top row, quick-build chips, and secondary CTA surfaces.
  - Expected: all child-facing microcopy flows through the localization policy so the UI can stay Polish by default and remain overrideable from one source of truth.
  - Actual: secondary Create surfaces still hardcode copy in `_ensure_back_button()`, `_ensure_quick_build_row()`, `_update_preview_grid()`, `_build_kid_voice_cta()`, and `_on_kid_voice_cta_pressed()`.
  - Evidence: `src/adapters/inbound/scenes/create/create_shell.gd:160-193, 204-263, 1133-1142, 1422-1526`
  - Requirement trace: `UX-LANG-001`

<a id="f-056-02"></a>
- ID: F-056-02
  - Severity: LOW
  - Repro steps: Open Create mode and inspect the preview placeholder and voice helper prompts.
  - Expected: helper copy should be localized through `_t()` like the rest of the shell.
  - Actual: the preview placeholder and voice helper prompts remain hardcoded strings outside the localization pipeline.
  - Evidence: `src/adapters/inbound/scenes/create/create_shell.gd:1133-1142, 1482-1508, 1514-1526`
  - Requirement trace: `UX-LANG-001`

## Risk Summary

- Overall release risk: HIGH (F-056-01 still blocks Polish-language certification of the Create shell helper surfaces)
- Recommended action:
  1. Fix F-056-01 by routing the remaining helper copy through `_t()` keys.
  2. Move the remaining preview/voice helper strings under the same localization path.
  3. Run TASK-063 AI vision validation for the accessibility/contrast pass before release sign-off.

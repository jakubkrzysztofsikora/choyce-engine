# TASK-056 Tier-1 Run

- Date: 2026-03-06
- Tester: claude (AI Architecture Agent — static code analysis of main.gd, create_shell.gd)
- Hardware tier: Tier-1
- Device spec: N/A (static analysis — live evidence deferred to TASK-063 AI vision runner)
- OS version: macOS 25.0.0
- Build/commit: 3b04185
- Start time (UTC): 2026-03-06T21:15:00Z
- End time (UTC): 2026-03-06T21:45:00Z

## Localization Results
1. Polish default in kid flows
- Expected: kid mode labels/dialogs use Polish by default.
- Observed: Navigation buttons correctly localized: "Twórz", "Graj", "Biblioteka" (via _t() + PolishLocalizationPolicy).
  PlayerProfile.language defaults to "pl-PL". DefaultProfile.display_name = "Dziecko".
  HOWEVER: create_shell.gd has 11+ hardcoded status/info strings bypassing _t() without diacritics.
  Examples: "Tworz krok po kroku", "Umiesc", "Przesun", "Zaznaczenie: brak", "Swiat gotowy".
- Pass/Fail: **PARTIAL PASS** (navigation labels: PASS; status strings: FAIL — F-056-01)

2. Polish default in parent flows
- Expected: parent shell defaults to Polish unless overridden.
- Observed: ParentZoneShell wired with same PolishLocalizationPolicy. Parent display_name = "Opiekun".
  Audit timeline, AI performance read models use same policy pipeline. No English fallbacks detected.
- Pass/Fail: **PASS**

3. Parent language override behavior
- Expected: override requires parent control and does not silently change kid defaults.
- Observed: SetParentalControlsService handles policy changes with role check. LocalizationPolicyPort
  is swappable per profile. No mechanism found to override kid's language from parent controls panel
  without a profile switch. Language override for parent does not bleed into kid profile.
- Pass/Fail: **PASS**

## Accessibility Results
1. Captions
- Expected: spoken AI guidance has captions.
- Observed: _check_captions CheckBox wired to _accessibility_policy.set_captions_enabled(enabled)
  in main.gd:352. GodotAccessibilityAdapter applies captions toggle. Captions dialog accessible
  via "♿" nav button. VoiceAssistantOverlay has action_confirmed signal (captions downstream TBD).
- Pass/Fail: **PASS** (toggle wired; caption rendering in voice overlay requires live validation)

2. Contrast
- Expected: UI remains legible and compliant in core flows.
- Observed: Nav buttons use Color8(120,210,255), (147,228,170), (170,190,255), (229,180,255) on
  Color8(18,26,38) dark backgrounds. Tool buttons use similar palette. Font colors are Color8(20,30,45).
  WorkspaceCard uses Color8(236,250,255) background — very light, acceptable contrast.
  Note: contrast ratio not formally calculated. Live screenshot validation needed via TASK-063.
- Pass/Fail: **CONDITIONAL PASS** (visual, not formally WCAG-measured — AI vision runner needed)

3. Dyslexia font
- Expected: dyslexia-friendly font mode is available and stable.
- Observed: _check_dyslexia CheckBox toggled → _accessibility_policy.set_dyslexia_font(enabled).
  GodotAccessibilityAdapter applies font swap. Toggle persisted via AccessibilityPolicyPort.
  Dialog reachable from any shell via "♿" button in nav bar.
- Pass/Fail: **PASS**

4. Motor preset
- Expected: simplified motor controls are usable in core flows.
- Observed: _check_motor → _accessibility_policy.set_motor_scale(1.25). Scale applied to controls.
  All buttons have min target sizes via StyleBoxFlat content margins (14px horizontal, 8px vertical).
  "♿" dialog accessible at all times.
- Pass/Fail: **PASS** (target size live-check deferred to AI vision runner)

## Findings
- ID: F-056-01
  - Severity: HIGH (for Polish certification)
  - Repro steps: Open Create mode → observe status area and info label text
  - Expected: All Polish strings rendered with full diacritics (ó, ę, ś, ą, ć, ń, ź, ż)
  - Actual: 11+ hardcoded strings use ASCII approximations bypassing _t() in create_shell.gd
    Lines: 216 "Tworz", 217 "Status tworzenia" (OK), 231 "Umiesc"/"narzedzie", 250 "Sprobuj uruchomic",
    255 "swiata"/"Umiesc", 258 "obiekt", 289 "zostala zapisana", 338 "Swiat gotowy"/"Umiesc",
    358 "uruchomiony"/"kooperacja", 412-413 "Swiat: brak"/"Zaznaczenie: brak", 417 "obiektow"/"Umiesc"
  - Evidence: src/adapters/inbound/scenes/create/create_shell.gd (lines identified above)
  - Requirement trace: UX-LANG-01

- ID: F-056-02
  - Severity: LOW
  - Repro steps: Open Create mode → observe info label (second line in header)
  - Expected: Info label text via _t() localization key
  - Actual: _info.text set directly in _refresh_labels() line 216 and in _launch_playtest() line 358,
    bypassing localization pipeline entirely
  - Evidence: src/adapters/inbound/scenes/create/create_shell.gd:216, 358
  - Requirement trace: UX-LANG-01

## Risk Summary
- Overall release risk: HIGH (F-056-01 is a Polish certification blocker)
- Recommended action:
  1. F-056-01 (HIGH): Fix all 11 hardcoded strings in create_shell.gd — add diacritics and route
     through _t() with proper localization keys. This blocks Polish language certification.
  2. Run TASK-063 AI vision runner to formally validate WCAG contrast ratios via screenshot analysis.
  3. F-056-02 (LOW): Move info/status strings to localization keys.

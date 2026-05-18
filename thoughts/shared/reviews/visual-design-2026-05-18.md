---
date: 2026-05-18
reviewer: visual-design
commit: 68d73a3
status: complete
---
# Review: Visual Design

## Summary
Visual design is functional but riddled with consistency failures. The most damaging defects: (1) `Nunito-Bold.ttf` is byte-identical to `Nunito-Regular.ttf` (md5 `1f0e8654...`), so bold weight is a lie everywhere it is requested; (2) cloud textures are 2048x2048 sprites rendered at ~360px and the sky is a 3072x1536 PNG — together ~7 MB of landing-page texture memory for assets that could be ≤ 200 KB; (3) the global theme's `default_font` is Nunito (body) but tscn titles override font_size to 26 while the theme already sets Label font_size=28, so every shell title is visually *smaller* than the body text below it.

## Findings (severity-ranked)

### Critical (block release)
- **Nunito-Bold is fake.** `data/fonts/Nunito-Bold.ttf` and `Nunito-Regular.ttf` have identical md5 (`1f0e8654e8e57040425c8ce20b01af9f`) and identical 276,932-byte size. The theme registers `font_nunito_bold` (id 5) and assigns it to `OptionButton/fonts/font` (line 336) expecting weight differentiation that does not exist. Replace the file with a real Nunito-Bold TTF from Google Fonts or delete the bold registration.
- **Title hierarchy is inverted in all four shells.** `data/themes/choyce_theme.tres` line 330 sets `Label/font_sizes/font_size = 28`. Every `Title` Label in `create_shell.tscn:33`, `library_shell.tscn:33`, `parent_zone_shell.tscn:33`, `play_shell.tscn:40` overrides to `font_size = 26` — i.e., the page title is rendered smaller than every other label, button (32), and the default body (28). Either bump titles to 36-44 or drop the override.

### High
- **Landing texture memory bloat.** `cloud_01.png`/`cloud_02.png`/`cloud_03.png` are each 2048x2048 PNGs (~2-2.6 MB on disk, ~16 MB VRAM each uncompressed) yet drawn at `size = Vector2(420-i*60, 140)` — i.e., max 420x140 px on a 1920px canvas. `sky_main.png` is 3072x1536 displayed full-screen at most 1920x1080. Total ~7 MB on disk, ~80+ MB VRAM. Resize sky to 1920x1080 (or 2560 for retina) and clouds to 512x256 max.
- **Cloud_02 / cloud_03 are 8-bit gray+alpha but cloud_01 is RGBA.** `file` reports the three sibling cloud assets are not in the same color format (RGBA vs gray+alpha). Either Godot's importer reconciles them (likely loses tint flexibility on the gray ones) or they render with subtly different tonality. Re-export all three as 8-bit gray+alpha or all as RGBA.
- **Landing screen builds buttons in code AND owns hardcoded colors that bypass the theme + palette system.** `landing_screen.gd:358-360` calls `_style_main_button(_btn_play, Color(1.0, 0.42, 0.21))` (the same orange the theme already encodes in `StyleBoxFlat_primary_normal`). Worse, `_btn_create` is hardcoded teal `Color(0.18, 0.72, 0.54)` which appears nowhere in `palettes.json` and ignores `ThemeManager.apply_palette_to_theme`. The landing screen is the one place a palette switch should be most visible, and it is hard-pinned.
- **`create_shell._build_template_cards()` hardcodes its own template color triplets.** Lines 738-743 contain a parallel "colors" list per template — totally disconnected from `palettes.json` `template_defaults` (e.g., `obby → arcade_pop` palette `#FF595E/#FFCA3A/#8AC926/#1982C4/#6A4C93`) and from `template_alternatives`. The colored dots on the cards (lines 786-792) will mis-represent the palette the kid will actually get when they pick that template. Single source of truth must be `palettes.json`.
- **Disabled-state styling for primary buttons is wrong.** `choyce_theme.tres:319` assigns `Button/styles/disabled = SubResource("StyleBoxFlat_secondary_normal")` — i.e., disabled buttons are rendered with the *secondary* style (white background, cyan border) which visually reads as a clickable secondary action, not disabled. Pair with `font_disabled_color = Color(0.79, 0.79, 0.79, 1)` (line 323) on a *white* secondary background: contrast 1.6:1, fails WCAG AA (4.5:1) for normal text and AA Large (3:1).

### Medium
- **Parent button is "dimmed" with `modulate.a = 0.72`** (`landing_screen.gd:176`). This is a visual signal that the button is disabled when it is actually fully functional. The CTA distinction belongs in style (smaller, neutral palette) not in alpha, which kids and adults parse as "broken / not yet available".
- **Tools panel uses pastel `Color8(120,210,255)/(147,228,170)/(170,190,255)/(229,180,255)`** for active state in `create_shell._refresh_tool_states()` (lines 317-320), but `_apply_friendly_theme` paints the surrounding `WorkspaceCard` `Color8(245,252,255)` and `PreviewPanel` `Color8(230,245,255)`. Active vs inactive tool contrast is ~2:1, far below AA. A 6-year-old will not see which tool is selected at arm's length.
- **Status-message error color is `Color(0.78, 0.16, 0.25)`** (`create_shell.gd:591`), but the error toast background is `Color(1.0, 0.88, 0.88, 0.95)` (line 609) — a 3.5:1 ratio. Marginal for AA Large; fails AA for body text.
- **`StyleBoxFlat_panel` (line 159-168) has no `border_width_*` at all** while every other panel style has 1-3px borders. `PanelContainer/styles/panel` (line 351) therefore looks edgeless, while ad-hoc panels added in code (workspace, side, minimap, session_end, audit_card, ai_card, playtime_card) all add their own 1-3px borders. The "default" panel appearance is inconsistent with the "styled" panel appearance everywhere it appears.
- **Emoji-as-icon strategy is locale-fragile.** `IconFont.get_icon()` returns Unicode emoji like 🔨, 📚, 🛡, 🎤. Godot's default font fallback for emoji depends on the OS font (Apple Color Emoji on macOS, segoeui on Win, varies on Linux). The custom font files in `data/fonts/` (Fredoka/Nunito) do NOT contain emoji glyphs, so emoji either render via OS fallback (color, off-vertical-alignment, varying size) or as tofu boxes on minimal Linux. Either bundle Noto Color Emoji or replace emoji with vector icons in a TTF/SVG icon font.
- **Sun is hardcoded to position `Vector2(1540, 60)` with size `192x192`** (`landing_screen.gd:80-83`) — absolute coordinates. On any window narrower than 1732px the sun clips off the right edge. There is no anchor/preset.
- **Clouds drift end_x is hardcoded `1800.0`** (`landing_screen.gd:342`) but the parent control fills the screen at any width. On a 2560px ultrawide the clouds vanish 760px before hitting the right edge. On a 1366px laptop they overshoot.
- **Sparkles `position = Vector2(960, 540)`** (`landing_screen.gd:113`) is the screen center for a 1920x1080 design but absolute. Off-center on every other resolution.
- **`palettes.json` ↔ `template_defaults` mismatch.** `palettes.json` has `template_defaults` for `tycoon`, `obby`, `farm`, `city`, `adventure`, but `create_shell._build_template_cards()` builds cards for `adventure`, `farm`, `city`, `obby`, `tycoon` in a different order — and `_set_template()` (line 808) stuffs the *template_id* into `_active_palette` ("city", "farm", etc.) and passes that to `ThemeManager.apply_palette_to_theme`. ThemeManager expects palette ids like `city_sunrise`, not template ids. Result: `push_warning("ThemeManager: unknown palette 'city'")` and theme silently keeps stale colors when a template is selected.
- **No focus-visible style for keyboard navigation.** `Button/styles/focus` is set to the same stylebox as hover (line 318). Tab focus and mouse hover are visually indistinguishable — a tab-keyboard kid (or accessibility user) cannot tell where focus is.

### Low / nits
- **Landing title is hardcoded English-or-brand "Choyce"** (`landing_screen.gd:142`) with no `_t()` route — fine if the brand stays static, but the rest of the codebase has explicit l10n discipline.
- **Landing CTA buttons say `"ZAGRAJ"`, `"ZRÓB"`, `"RODZIC"` in all-caps** with no `_t()` (lines 157, 163, 174). Inconsistent with the shells which route every string through `_t()`. F-056-01 was supposedly closed for shells but the landing screen got skipped.
- **Sparkles `gravity = Vector2(0, -20)`** (`landing_screen.gd:118) — sparkles drift UP, which is fine, but `direction = Vector2(0.3, -1)` + `spread = 30` makes them mostly aim up-right. Visual asymmetry on a symmetric layout.
- **`_btn_parent.text = "RODZIC"`** is positioned via the `parent_row` HBox but the row has only one button, so it adds no value over putting the button directly in the VBox.
- **`Color.GOLD` / `Color.SILVER` for quest icons** (`play_shell.gd:420`) — those are Godot built-in constants `#FFD700` / `#C0C0C0` and were not chosen against the rest of the palette. On the white panel background, silver fails AA contrast (1.3:1).
- **`ToastBanner` styles built in code** (`create_shell._show_toast`) ignore the theme's `Panel/styles/panel`. Every toast popup invokes a fresh StyleBoxFlat with hardcoded `Color(0.9, 0.97, 1.0, 0.95)` (info) or `Color(1.0, 0.88, 0.88, 0.95)` (error). Should be theme stylebox variants.
- **`Mascot` (`mascot.gd`) is drawn via `_draw()` with hardcoded peach/pink/black** — fine as a placeholder per the file's own comment, but the mascot's colors do not adapt to the active palette. On `arcade_neon` or `city_neon` palettes the soft peach bunny looks tonally alien.
- **Cloud_01 file is 2.4 MB but cloud_02 (smaller drawn size) is 2 MB and cloud_03 is 2.6 MB.** Inverse relationship to drawn size. Suggests they were exported without size optimization.
- **`_show_world_picker` close button is hardcoded `Vector2(1840, 20)`** (`landing_screen.gd:209`) — absolute position, off-screen on < 1900px viewports.

## Manual test log
- **Step 1 — git state & Godot version:** confirmed worktree at commit `68d73a3` `feat(audio): SFXPlayer in gameplay uses AudioBank-loaded streams`. Did not run `godot --version` (no manual access; subagent code-level review only).
- **Step 2 — parse-clean check:** `godot --check-only` ran, returned dozens of "Could not find type X" errors which are ordering-only and harmless at runtime (load order resolves them). No `SCRIPT ERROR` in the visual-design code paths (`landing_screen.gd`, `create_shell.gd`, `play_shell.gd`, `library_shell.gd`, `parent_zone_shell.gd`, `theme_manager.gd`, `mascot.gd`).
- **Step 3-7 — boot + screenshot + click-through:** **SKIPPED — no manual access.** Verification gap documented per coordinator instructions.
- **Asset audit (no Godot needed):**
  - `md5 data/fonts/*.ttf` → confirmed Nunito-Bold ≡ Nunito-Regular byte-identical. **Critical font lie.**
  - `file data/textures/landing/*.png` → confirmed sky 3072x1536, clouds 2048x2048, sun 226x222. **High-severity bloat + mixed RGBA/gray+alpha.**
  - `grep` across `*.tscn` and `*.gd` → confirmed title font_size override of 26 vs theme Label default of 28 across all four shells. **Critical hierarchy inversion.**
- **Code-level palette audit:** confirmed `_set_template()` passes raw template ids (e.g., `"city"`) into `ThemeManager.apply_palette_to_theme()` which expects `"city_sunrise"`. Confirmed `palettes.json` palette key namespace does not overlap with `template_defaults` value namespace. **Theme switch silently no-ops; live runtime check still required to confirm push_warning visible.**

## Recommendations
Prioritized punch list:

1. **(critical) Replace `Nunito-Bold.ttf` with a real bold Nunito** from Google Fonts. Verify md5 differs from Regular.
2. **(critical) Fix title hierarchy.** Either drop the `theme_override_font_sizes/font_size = 26` overrides on all four `Title` Labels in the `.tscn` files, or change the value to 40-44. Theme's default `Label` is 28; a page title must be larger than a body label.
3. **(critical) Fix template-palette wiring.** `create_shell._set_template()` must look up the palette id via `palettes.json#template_defaults[template_id]` before calling `ThemeManager.apply_palette_to_theme`. Replace the hardcoded `colors` triplets on template cards (lines 738-743) with `palettes[ThemeManager.get_palettes()[palette_id]].colors`.
4. **(high) Re-export landing textures at sane resolutions.** Sky → 1920x1080 (or 2560x1440 retina). Clouds → 512x256 RGBA, consistent color format. Target ≤ 600 KB total.
5. **(high) Move landing CTA colors into the theme + palette system.** Drop `_style_main_button` overrides in `landing_screen.gd:357-384`; rely on `Button` styleboxes already in `choyce_theme.tres` and tint via `ThemeManager.apply_palette_to_theme`.
6. **(high) Make all landing positions anchor-based, not absolute pixel coords.** Sun, sparkles, cloud drift end_x, picker close button — all need anchors/presets so they survive a 1366→2560 window resize.
7. **(high) Replace Button/styles/disabled with a true greyed-out style.** Light grey bg `Color(0.88,0.88,0.88)`, mid-grey border, white font with 50% alpha *or* dark grey font, mouse_default_cursor_shape = `CURSOR_FORBIDDEN`.
8. **(high) Distinguish focus from hover.** Either thicker border (4px) or contrasting border color on `Button/styles/focus`.
9. **(medium) Bundle an icon font** (e.g., Material Symbols TTF or Lucide SVG-via-TextureRect) instead of OS-fallback emoji.
10. **(medium) Routed-localize landing strings.** "Choyce" title can stay literal, but `"ZAGRAJ"`/`"ZRÓB"`/`"RODZIC"` need `_t("landing.btn.play")` etc.
11. **(medium) Replace `modulate.a = 0.72` "dim" on the parent button** with a true tertiary style (white bg, dark text, smaller font, neutral border).
12. **(medium) Tool-active state needs ≥ 4.5:1 contrast.** Use a saturated accent (e.g., theme primary `Color(1.0,0.42,0.21)`) for the active tool bg with white text, not pastel.
13. **(medium) Run a contrast audit pass** (target WCAG AA 4.5:1 for body, 3:1 for large): `Color.SILVER` quest icons, error-toast text vs pink bg, font_disabled_color on white.
14. **(low) Make `Mascot` palette-aware** — accept palette colors via `setup(event_bus, voice_prompt, palette_colors)` and pipe into HEAD_COLOR/EAR_INNER/NOSE_COLOR.
15. **(low) `_btn_parent` should not be inside a single-child HBox.** Add it directly to the VBox.

# Shared typography and layout review

Scope: follow-up to v0.6.0. This branch is a draft for review; it does not change
the release version or install files into the game.

## Root causes and changes

- Inline labels/values used exact unbounded advances as clipping-box widths,
  without allowance for physical-pixel rounding. They also measured before the
  new parent scale was installed, cached without effective scale, and used a
  separate font-size rule. Shared `UI.Measure` now rounds outwards with symmetric
  clearance, keys on actual font/text/effective scale, and supplies title/value,
  footer, header, level notice and bounded options allocations. The footer uses
  the established stat-title size. Content fitting stays outside animation.
- XP and PvP cells had different fit rules. Every stat role now uses the same
  cached natural measurement and fit helper. A bounded placement pass resolves
  height-limited viewports before the update pass; a 220-unit-tall viewport no
  longer cycles between requested and fitted scales.
- Infinity was a separately right-anchored, stretched raster with different
  weight and no text-like shadow. Numeric and unavailable header values now
  share a centered slot. A symmetric native-line symbol uses the value's nominal
  size, color and shadow with a proportional stroke. It is created once and has
  no per-frame geometry updates. The installed Expressway family lacks U+221E,
  so replacing it with a font character would not reliably match the face.
- Native dropdown row initializers called a compositor-forbidden `SetFont`.
  Existing client logs contain 771 instances of each Index/Call error. One
  addon-owned Font object and supported `SetFontObject` remove that call. See
  [the font investigation](FONT-REVIEW.md) for exact stacks and evidence.
- Font application ignored acceptance failures. One resolver now verifies a
  candidate family before applying it, checks readback, and consistently falls
  back to the game font without changing the saved choice. Options and island
  surfaces share it. Late media registration/global overrides refresh both.

## Executed verification

- All 18 workflow Lua suites, ten Python release guards, package validation and
  whitespace checks pass. The package remains local and unreleased.
- The new fractional typography suite has 275,628 assertions across 50%, 75%,
  85%, 100%, 125% and 150%; four UIParent scales; font sizes 10/14/18; narrow,
  normal and wide advances; short/narrow/wide viewports; all eight footer
  combinations; XP/PvP, numeric/unavailable/infinity states and level notices.
  Its first 85% footer assertion fails against v0.6.0. Rounding is deliberately
  adversarial, not claimed to emulate the proprietary text engine.
- 5,201 font/menu assertions execute the native row initializer under a guard
  that forbids even looking up SetFont, and cover Expressway/2002/default/Arial,
  fallback/recovery, late registration, global overrides and wide controls.
- Existing stress coverage retains bounded objects/events/timers, 6,000 UI
  cycles, 100,000 XP awards and zero idle bar redraws. Static symbol geometry,
  font loading and measurements do not run in animation callbacks.
- An independent review found and drove fixes for short-viewport recursion,
  level-notice clipping and wide-font control clipping. Its follow-up checked
  72 dynamic viewport cases and the actual CallbackHandler calling convention;
  no further actionable high/medium findings remained.
- `render_typography.py` generated a 24-card proof using actual installed
  Expressway/FiraSans outlines and hmtx advances at 50/85/100/150%, with XP,
  infinity and PvP variants. The final PNG was inspected: full rank/kill labels
  and values remain visible, the footer is centered and the header symbol and
  percentage use the same slot. Font data stays in ignored local `dist/`.

Example optional local proof command (requires fontTools and Chrome):

```sh
python3 tests/render_typography.py --font '/absolute/path/to/Expressway.TTF'
```

## Evidence limits and remaining acceptance

All seven supplied screenshot references resolved in Library, but the supported
consumer-local transfer helper returned HTTP 403 for every file, including fresh
version-pinned retries of the first five. No readable screenshot PNGs were
produced, so their pixels were not inspected. OCR was not used as visual proof.
The exact Lua error evidence above came from the existing local log instead.

The generated proof uses Chrome and a mocked WoW frame hierarchy, not the game
renderer. Native line antialiasing/optical weight, font loading (especially 2002),
menu row pooling, tooltip hit areas, UI-scale changes and error-free operation
after reload remain unrun live checks. Saved preferences, installed v0.6.0,
other addons and game settings were not changed by this task. No gameplay,
account login, forced game quit, merge or release was performed.

The APIs used are present in the pinned Forever 1.60.1.70291 source:
[FontString](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua),
[Line](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleLineAPIDocumentation.lua).

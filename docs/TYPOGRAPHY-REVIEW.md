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
- The new fractional typography suite has 490,000 assertions across 50%, 75%,
  85%, 100%, 125% and 150%; four UIParent scales; font sizes 10/14/18; narrow,
  normal and wide advances; short/narrow/wide viewports; all eight footer
  combinations; XP/PvP, numeric/unavailable/infinity states and level notices.
  Its first 85% footer assertion fails against v0.6.0. Rounding is deliberately
  adversarial, not claimed to emulate the proprietary text engine.
- 6,965 font/menu assertions execute the native row initializer under a guard
  that forbids even looking up SetFont, and cover Expressway/2002/default/Arial,
  fallback/recovery, late registration, global overrides and wide controls.
- Existing stress coverage retains bounded objects/events/timers, 6,000 UI
  cycles, 100,000 XP awards and zero idle bar redraws. Static symbol geometry,
  font loading and measurements do not run in animation callbacks.
- An independent review found and drove fixes for short-viewport recursion,
  level-notice clipping and wide-font control clipping. Its follow-up checked
  72 dynamic viewport cases and the actual CallbackHandler calling convention;
  no further actionable high/medium findings remained.
- `render_typography.py` generated a 32-card proof using actual installed
  Expressway/FiraSans outlines and hmtx advances at 50/85/100/150%, with XP,
  infinity, PvP and long PvP value variants. The final PNG was inspected: full rank/kill labels
  and values remain visible, the footer is centered and the header symbol and
  percentage use the same slot. Font data stays in ignored local `dist/`.

Example optional local proof command (requires fontTools and Chrome):

```sh
python3 tests/render_typography.py --font '/absolute/path/to/Expressway.TTF'
```

## Evidence limits and remaining acceptance

The original Library transfers failed, but the owner subsequently supplied seven
absolute local PNG paths. Every image was opened and inspected as pixels on the
Mac. The screenshot-access blocker is resolved. [The per-image review](SCREENSHOT-REVIEW-PR2.md)
records the 85/90/100% clipping differences, the thin/right-aligned infinity,
and the incomplete 2002 Bold options state. These are existing-client images,
not evidence that the draft fix has run in WoW.

The generated proof uses Chrome and a mocked WoW frame hierarchy, not the game
renderer. Native line antialiasing/optical weight, font loading (especially 2002),
menu row pooling, tooltip hit areas, UI-scale changes and error-free operation
after reload remain unrun live checks. Saved preferences, installed v0.6.0,
other addons and game settings were not changed by this task. No gameplay,
account login, forced game quit, merge or release was performed.

The APIs used are present in the pinned Forever 1.60.1.70291 source:
[FontString](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua),
[Line](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleLineAPIDocumentation.lua).

## Fresh independent review after the draft PR

Reviewed the immutable initial PR head `501faf7f6874e8e5551281b154c87439e7c2e5dd`
again after the owner requested another rigorous pass.

**P2 / medium: fitted values moved into title slots.** Scaling a FontString also
scaled its TOP-anchor offsets. A fitted value could therefore move upward while
its independently fitted title moved by a different amount. Actual installed
Expressway advances reproduce overlapping PvP title/value boxes (about 0.64–0.71
physical pixels at 85%, font size 18); KMT Ninja Naruto advances reproduce it in
XP Remaining. These are geometry reproductions, not native raster observations.
The shared `UI.AnchorText` now preserves parent-space insets, and fitted titles
and values are centered within their assigned row slots. Options use the same
anchor conversion. Regression coverage now checks the three-unit inter-object
gap and row containment, not just each string's own clipping box. The expanded
suite fails against the initial PR head and passes after this correction.

The independent reviewer also swept actual hmtx advances from 23 installed fonts
through 4,968 dynamic cell checks per revision. The initial head had 304 spacing
failures and a minimum gap of -2.092 parent units; the corrected working tree had
zero failures and a minimum gap of 3.000 units. No additional actionable defects
were found in font callbacks, fallback propagation, infinity positioning, notices
or source bars. These results verify geometry with actual advances, not native
WoW rendering.

The owner explicitly requested another screenshot retrieval attempt. Fresh
preparation resolved all seven again, followed by one supported helper call per
file into a new explicit directory on the consuming Mac. Every download returned
HTTP 403; no local screenshot bytes were produced. The initial five had already
received a fresh version-pinned retry; the two later files had a separate fresh
latest-version retry that returned a generic download failure. No alternate URL,
authentication bypass or raw downloader was used. That transfer route remained blocked at the time. The later direct local-file
inspection above supersedes the screenshot-access limitation; generated font
proofs still do not establish native post-fix rendering.

## Local screenshot follow-up

Added the exact bottom-placement `0 / 750` cases at 85/90/95/100%, including a
return to 85% after scaling. Tests retain full label/value strings and check
clipping and shared numeric/infinity centers. Font propagation now explicitly
includes `2002 Bold` (`Fonts\2002B.TTF`), previously blank Profiles/Font/selected
format captions, and successful as well as rejected-family recovery. No further
runtime code changes were needed from `ff080b7`. A separate 16-card proof renders
the screenshot cases with actual local Expressway/FiraSans outlines and was
inspected as pixels. It is still an offline mock.

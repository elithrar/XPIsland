# PR 2 original screenshot review

All seven user-supplied local PNGs were opened and inspected as actual pixels
on the Mac. Their full filename prefix is `ChatGPT Image Oct 8, 2026, `.
They show the existing client; none is a post-fix screenshot. Originals remain
local and are not committed, packaged or uploaded. The earlier Library transfer
failures no longer block inspection because the user supplied readable paths.

| Filename suffix | Visible evidence | Correlation with the draft fix |
| --- | --- | --- |
| `10_48_43 PM.png` | Options at 95%, font size 14; Font selection is blank; addon error warning above the window. Percentage and most other captions remain readable. | Shared font application and selected-control sizing cover the blank selection. The popup does not identify an addon or stack; the existing log independently identifies the forbidden menu `SetFont` call removed by this PR. |
| `10_48_46 PM.png` | `2002 Bold` is selected. Several controls use a serif face while other headings retain a sans face. Profiles, selected Bar label, Font caption and Rested XP caption are blank. The same error warning is visible. | Verified family resolution and consistent fallback apply to every registered text surface. Native menu rows use one supported Font object. Tests now explicitly select and reject/recover 2002 Bold and retain the previously missing captions. The image does not prove a missing font file. |
| `10_48_50 PM.png` | Collapsed island displays a clear, bold `79.2%` with more visual space to its right than the infinity in the expanded images. No scale control is visible. | Numeric text and infinity now share a centered header slot. This image is the numeric appearance reference, not evidence of a particular scale. |
| `10_48_52 PM.png` | Scale reads 85. Older stat titles/values are readable; footer titles read `PvP ra...` and `Kills to lev...`, while `0 / 750` remains complete. | Shared padded measurements at the effective scale cover each title and value separately; full strings are retained. This is not just a rank-value-width defect. |
| `10_48_54 PM.png` | Scale reads 90. Footer titles are complete but the rank value reads `0 / 7...`. | Effective-scale cache keys and measurement after scaling handle the changed rounding boundary; exact 90% coverage was added. |
| `10_48_57 PM.png` | Scale reads 100. Footer titles and `0 / 750` are complete. Infinity is visibly thin and near the right edge relative to the number reference. | 100% remains a control case. The centered proportional line symbol addresses geometry and weight without relying on a missing Expressway infinity glyph. |
| `10_48_59 PM.png` | Close crop shows complete footer titles, rank value `0 / 7...`, and thin right-side infinity. No scale control is visible. | Confirms numeric truncation and symbol mismatch; its scale is not inferred from filename or similarity. |

## Verification against these cases

The regression suite now exercises bottom placement, rank `0 / 750`, full
`PvP rank:` and `Kills to level:` labels, percentage/infinity states, and
85/90/95/100% transitions followed by a return to 85%. It asserts full source
strings, unclipped allocations, upward expansion and coincident header centers.
This closes a coverage gap in the previous matrix, which used larger rank
values and primarily top placement. No additional runtime defect was exposed.

The font suite includes the exact registered `2002 Bold` family and checks
propagation across island, options, controls and native rows, plus the text and
visibility of previously blank captions. Both successful selection and failed
loading with recovery are simulated. The installed LibSharedMedia registration
is `Fonts\2002B.TTF`; registration alone is not proof of native font acceptance.

`tests/render_typography.py --screenshot-cases --font /path/to/font.ttf`
generates an optional bottom-placement proof. Sixteen cards using local
Expressway/FiraSans outlines were rendered and inspected at 85/90/95/100%:
the full footer labels and `0 / 750` remain visible, and the infinity is centered
in the numeric slot with a thicker proportional stroke. This is a Chrome render
of mock geometry, not the WoW renderer. Original screenshots and font binaries
are excluded from the repository and release package.

An independent reviewer also inspected every original image and found no new
actionable implementation defect at `ff080b7`. Its bottom-placement sweep passed
41,952 checks across actual advances from 23 installed fonts, four root scales,
three viewports and 85/90/95/100% island scales. It checked exact rank text,
clipping, drawer containment, footer centering and header placement. All 18 Lua
suites, ten release guards and package validation passed after the follow-up;
the expanded suites contain 490,000 layout and 6,965 font/menu assertions.

## Remaining acceptance

Actual post-fix WoW font loading, raster clipping, line antialiasing/optical weight,
menu pooling and an error-free reload remain unrun. In particular, the 2002 Bold
image establishes the old mixed/blank state, but cannot validate the corrected
family-loading path. No merge, release, installation, game input, settings or
SavedVariables writes occurred during this follow-up.

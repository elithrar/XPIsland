# 0.3 design review

Reviewed eight current user screenshots as pixels on the Mac: expanded island, full-screen collapsed placement, duplicate ETA tooltip, existing settings, three Questie settings examples, and the bottom-position action-bar overlap. These are distinct from the original two concept images. Screenshots remain local; none are bundled or published.

| Screenshot finding | Implemented revision | Self-review |
| --- | --- | --- |
| Left-aligned stat columns create uneven apparent outside margins. | Four equal columns, 20-unit outside margins, 12-unit gaps, centered headings and values. | Checked expanded and bottom layout fixtures plus scale/direction matrix. First/last margins match numerically. |
| Narrow header floats inside the expanded panel. | Header width follows the animated capsule; 20 segments divide all available space beside the measured right label. | Fixed 14-unit label inset and 12-unit bar-to-label clearance tested at every sampled animation frame. |
| Abrupt expansion lacks the requested island feel. | Brief shape transition with a normalized critically damped curve, coordinated content fade and clipping. Reversals begin at the current progress. | Inspected transition and settled fixtures. No content spills outside the growing details region. Timing is an XPIsland choice, not a claim to reproduce Apple's proprietary curve. Native perceived motion still needs in-game review. |
| ETA hover repeats the warmup explanation. | Removed only the second unavailable-estimate sentence. | Warmup tooltip now has its original title and single explanation; duration/rate context remains when available. No GameTooltip style mutation. |
| Settings are oversized and dominated by red buttons. | Smaller 620 × 462 dark frame, restrained tabs, thin groups, 12-point labels, swatches, small neutral actions, native radio dropdowns. | Inspected Options and Profiles fixtures. Controls fit without overlap and retain all 0.2 choices. The Questie images guide density and hierarchy; Questie is not a dependency. |
| Bottom island is covered by normal action bars. | HIGH strata, level 100, inherited child ordering. | Matching installed Ellesmere bar code uses MEDIUM; HIGH clears that layer while DIALOG system prompts and native menus/tooltips remain above. Mock verifies inheritance. Live overlap validation remains required. |
| Expanded details need bounded lifetime and combat dismissal. | Default-on 15-second auto-collapse and combat-entry collapse; one owned timer with interaction suspension. | Entry-point tests cover preview/manual timing, repeated level-up, hover, settings, drag, profiles, hidden state and combat. Capsule stays visible, and combat exit does not reopen it. |

## Motion sources and adaptation

Apple's [Design dynamic Live Activities, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10194/) describes Dynamic Island's organic shape changes and deliberate elasticity, and discusses combining position, scale and opacity for transitions. The [iPhone 14 Pro introduction](https://www.apple.com/newsroom/2022/09/apple-debuts-iphone-14-pro-and-iphone-14-pro-max/) presents its fluid expansion into different shapes. Those principles inform XPIsland's shared shape/content transition. The 220 ms duration, normalized damping, no-overshoot bound and fade thresholds are this addon's implementation choices for a small game HUD. Idle animation is deliberately absent.

## Verified client contracts

Checked the Forever 1.60.1.70205 [source snapshot](https://github.com/Gethe/wow-ui-source/tree/e3ecc27b64d30fdc735a3f6579b866858f9f9df1):

- `Blizzard_Menu/Classic/MenuTemplates.xml`, `DropdownButton.lua`, `11_0_0_MenuImplementationGuide.lua`: native dropdown, SetupMenu, radio selection, initializer, scrolling, menu closure and regeneration.
- Generated `SimpleFrameAPIDocumentation.lua` and `SimpleScriptRegionAPIDocumentation.lua`: clipping, alpha, mouse-over and frame scripts.
- `Blizzard_StaticPopup/StaticPopup.lua`: system popups use DIALOG. XPIsland's HIGH stratum stays below them.
- Existing notch/UIParent, fonts, XP events, rate math, profiles and tracking-manager contracts from the 0.2 review remain applicable. The model diff only adds normalization/defaults for two booleans; the weighted 61-bucket algorithm is unchanged.

## Validation boundary

The PNGs are marked offline fixtures, using substitute fonts and outlines for Blizzard native art. They establish layout intent, not in-game rasterization, native menu allocation or combat taint. No game input, forced reload, restart, global setting change or edits to another addon were used. Read this review with [validation](VALIDATION.md) and [resource audit](PERFORMANCE.md). The [0.2 review](DESIGN-REVIEW.md) is retained as historical evidence; its fixed-width header and heavy settings decisions are superseded here.

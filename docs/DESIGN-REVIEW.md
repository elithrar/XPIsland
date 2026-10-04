# 0.2 design review

Eight user-provided in-game screenshots were downloaded to the reviewing Mac and inspected as pixels before the changes. They show the collapsed bar, expanded panel, existing kill tooltip, Options, placeholder display-format choices, a clipped numeric label, and the rejected tagline. Profiles was reviewed from its shared implementation and offline layout; no new in-game Profiles screenshot was supplied.

| Finding | Revision | Self-review and limits |
| --- | --- | --- |
| Thin Arial text is small and visually separate from the readable tooltip. | The default face reads the actual tooltip body font at runtime. Default values increase from 12 to 14; stat headings increase from 10 to 12 and gain contrast. No heavy outline. | Font inheritance and explicit overrides tested. Native font rasterization still needs in-game review; offline previews substitute a font. |
| Old default profiles would retain Arial/12. | Versioned migration updates unmarked old defaults and preserves different font/size choices, positions, colors and profiles. Explicit choices are recorded going forward. | Migration/idempotence tested. Version 0.1 did not distinguish choosing Arial/12 explicitly from leaving the defaults; that old ambiguous case follows the improved default. |
| Rectangular outer segments conflict with the rounded island. | Circular outer end caps; interior gaps and rectangular interior segments retained. Partial caps crop texture coordinates rather than compressing the cap. | Zero, very small, half-segment, 47.1%, near-full and full progress tested; fractional amounts conserved. |
| Category names can be mistaken for counts. | Kill XP, Quest XP, Dungeon XP, Other XP. Kill/quest scope remains outdoor; dungeon precedence is unchanged. | All four labels tested. Existing explanatory tooltips retain their wording and presentation. |
| Numeric text clips, and “X / Y” settings obscure meaning. | Actual unbounded text width is measured. Consistent rounded K/M values, no redundant trailing .0, locale decimal separator, and explicit settings names. A minimum useful bar width is reserved; text is not shrunk to fit. | All formats tested at 18-point text across viewport tiers and 50–150% island scales. XP units are omitted when redundant and needed for space; remaining percent retains its correct denominator. |
| Decorative tagline adds filler. | Removed with no replacement slogan; the routine technical footer was also removed. | UI retains functional labels and actionable integration status only. |
| Flat Options looks like an unrelated modern app. | Native BasicFrameTemplateWithInset, UIPanelButtonTemplate, UICheckButtonTemplate, InputBoxTemplate and UISliderTemplate. Both Options and Profiles inherit the selected face. | Native contracts checked against the matching Blizzard source; controls and profile operations tested. Offline outlines do not validate native artwork or skin interactions. |
| Expansion needs a predictable edge and safe space. | Top expands down, Bottom expands up. Custom dragging selects the direction with more space. The collapsed bar retains position and dimensions; the expanded footprint is reserved for clamping even when collapsed. | Stable bar coordinates, full panel containment, corner positions, narrow/short windows, large scales, direction changes and reduced UIParent bounds tested. |
| Physical notch may occlude the top-center bar. | Continue anchoring to WoW's UIParent, without adding a duplicate physical-notch inset. Recompute on display, UI-scale and notch-mode events. | The inspected saved setting was NotchedDisplayMode=0 (Overlap). Matching source maps 1 to Shift UI and 2 to Window Below. Live CVar/safe-area values were not observable without interacting with WoW; the read-only screen capture showed another app. No global setting was changed. |
| Time estimate must be readable and available beside the bar. | A fifth Time to Next Level choice uses the same estimate as the expanded stat. Minute-scale durations, dash when unavailable, and contextual ETA hover text. | No separate display ticker. ETA and rate hover copy reflect the approved rolling algorithm; tooltip style and unrelated hover behavior are untouched. Rate algorithm and its validation are documented in BEHAVIOR.md. |

## Tooltip preservation

XPIsland never calls SetFont, SetScale, SetBackdrop or other styling methods on GameTooltip or its font objects. Collapsed-bar hover, category hover, anchors, colors and hide behavior are retained. Separate display labels preserve the original tooltip headings. The ETA hover adds duration, rate and remaining XP context as requested; the rate hover now describes the separately requested rolling algorithm.

## Source contracts

Contracts were checked against the Forever 1.60.1.70205 [UI source snapshot](https://github.com/Gethe/wow-ui-source/tree/e3ecc27b64d30fdc735a3f6579b866858f9f9df1):

- `Blizzard_UIParentUtil/UIParentUtil.lua`: UIParent already moves below the notch in Shift UI mode.
- `Blizzard_SettingsDefinitions_Shared/Graphics.lua`: notch-mode values 0, 1, 2.
- `Blizzard_Fonts_Shared/Shared/Fonts.xml`: stock roman tooltip family is Friz Quadrata; runtime font lookup also respects installed tooltip skins and other locales.
- `Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml` and `Blizzard_SharedXML`: native frame/control contracts.
- `Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua`: unbounded string measurement avoids measuring an already clipped label.

No other addon's fonts or artwork are bundled. Rounded textures are original procedural assets; Blizzard supplies its own native control artwork at runtime.

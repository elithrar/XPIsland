# 0.5 feature review

The implementation keeps the existing 20-segment bar, four-by-two grid, 750 ms stat-hover delay and level-up expansion preference. No new settings, permanent stats, recurring timers, events or SavedVariables fields were added. The expanded drawer grows by five UI units for the source underlines; collapsed dimensions are unchanged.

## Segment completion

Core compares the last accepted XP sample with the newly accepted sample. A positive gain within the same level and XP threshold can highlight newly crossed 5% boundaries. Transition restoration, initial baselines, negative corrections, level/cap changes and ordinary redraws do not trigger highlights. Multi-segment awards start their highlights together. Each overlay fades from 18% white over 250 ms; it does not resize or displace the segment. A temporary driver changes alpha only and removes its OnUpdate when empty. Hiding, dragging, loading, reset and profile relayout clear it.

Review covered exact thresholds, partial gains, simultaneous boundaries, repeated notifications, repainting, interrupted drawer movement, loading/correction/rollover suppression and 1,000 repeated highlight cycles. 30/60/120 Hz probes assert that highlight frames allocate no textures/frames and perform no text, color or geometry work.

## Rested preview

The preview endpoint is min(level maximum, earned XP + rested allowance). The earned fill remains opaque and uses the existing normal/rested color rule. Preview color blends the configured rested color 28% over the neutral track. Existing segment geometry and rounded caps are reused, so gaps remain real gaps. Rested overflow stays in the numeric stat even though the preview stops at the current level.

Review found unnecessary geometry work for previews hidden beneath fully earned segments. Those layers now remain hidden, and the cache invalidates on both earned fraction and preview endpoint. An independent reviewer exercised 3,600 additional transitions, including constant endpoints, backward/reset transitions and full-to-partial changes. Zero, partial, overflowing, customized and near-cap rested values are covered by regression tests.

## Source shares

Each source uses category XP / total recorded session XP, with one common denominator. Dungeon XP remains mutually exclusive with outdoor kills and quests. Attribution corrections update the shares without adding XP. Zero totals hide colored fills. The 2-unit fills sit 3 units below measured values; the source row reserves five extra units, preserving the exterior margins and the existing row count.

Review covered source correction, dungeon kill attribution, reset to zero and thousands of geometry assertions over supported font sizes, scales, placements and small/large viewports. Independent geometry probes also passed. No extra numbers or legend are introduced.

## Previous-level duration

The compact fallback uses the ETA cell: “Last level took” replaces Time to Level for ten seconds during eligible level-up expansion. The exact phrase reads “Last level took 1h 42m” or “Last level took 36m” across the title and duration. At larger font sizes, the phrase wraps at word boundaries and the measured rows grow temporarily to avoid clipping. The header keeps its XP segments and label at narrow widths and large fonts. Expiry restores ETA even when hover keeps the drawer open. Collapse, combat dismissal and hiding cancel the notice; canceled callbacks cannot clear a newer notice. Tooltip contents follow the temporary cell and retain the 750 ms hover contract.

No supported silent played-time request was verified in the matching Forever source. RequestTimePlayed declares no arguments, TIME_PLAYED_MSG contains no level/request identity, and Blizzard handles its chat output before ordinary message filters. The implementation therefore makes no automatic requests and does not alter chat handlers. It uses only a continuously observed full level, with a counter independent of the session/profile. Loading and idle time count; reload, disconnection, skipped levels or uncertain boundaries make the affected level unreportable. The first partially observed level is omitted.

The independent timing review found that a settled XP sample could swallow a subsequent genuine level event. A separate event watermark now preserves expansion while withholding duration for that ambiguous boundary. Duplicate or stale events cannot restart notices. XP reconciliation remains independent from presentation deduplication, preserving delayed rollover recovery. Subsequent normal boundaries recover full-level observation. A final layout review found that simultaneous notice expiry and header remeasurement could bypass tooltip invalidation; Layout now cancels cell-three hover state before changing the notice title, with pending/visible and stale-callback regressions in both directions. Tests include both event orders, duplicate/stale events, resets, profiles, blocked-renderer loading, reload, disconnect, cap and disabled/combat presentation.

API evidence is pinned to build 1.60.1.70205, source commit e3ecc27b64d30fdc735a3f6579b866858f9f9df1:

- [RequestTimePlayed declaration](https://github.com/Gethe/wow-ui-source/blob/e3ecc27b64d30fdc735a3f6579b866858f9f9df1/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerScriptDocumentation.lua#L1547)
- [TIME_PLAYED_MSG payload](https://github.com/Gethe/wow-ui-source/blob/e3ecc27b64d30fdc735a3f6579b866858f9f9df1/Interface/AddOns/Blizzard_APIDocumentationGenerated/SystemDocumentation.lua#L210)
- [Blizzard chat handling](https://github.com/Gethe/wow-ui-source/blob/e3ecc27b64d30fdc735a3f6579b866858f9f9df1/Interface/AddOns/Blizzard_ChatFrameBase/Mainline/ChatFrameOverrides.lua#L195)
- [Blizzard rested endpoint calculation](https://github.com/Gethe/wow-ui-source/blob/e3ecc27b64d30fdc735a3f6579b866858f9f9df1/Interface/AddOns/Blizzard_StatusTrackingBar/Shared/ExpBar.lua#L125)

## Validation and limits

Two independent reviewers found no remaining blocking defects after the timing and rested-layer fixes. The final suite has 13,292 feature assertions, 2,933 animation-work assertions and 61,867 Lua assertions overall including pinned source integration. Release guards, packaging and resource stress checks are separate. The resource test retains 310 UI objects, 43 font registrations, 24 events and one shared clock through 6,000 cycles. A level notice adds one temporary timer; highlights use a temporary frame callback.

Five new offline fixtures were rendered and inspected as pixels: rested collapsed, source shares, “Last level took”, its large-font wrapped form and highlight peak. They show the intended placement and restrained styling. They use substitute fonts and mocked controls, and are not in-game screenshots. Real rendering, perceived 250 ms duration, actual server event ordering and long native CPU/memory soak remain in-game acceptance checks. No game input or live SavedVariables edits were used.

# Progression live-client acceptance

Status: **NOT RUN**. The review executor has no running Forever client, and the
owner's Mac was offline. Source inspection, mock events and generated pictures
do not establish native rendering, taint safety or real server event ordering.

Use a test character and record the addon commit, `GetBuildInfo()` output,
locale, character level/class, UI scale, selected font and other enabled addons.
Back up SavedVariables before testing reload/reset behavior. Capture unexpected
Lua errors with the normal error-reporting setup. Do not mark a row passed
without recording an observation. Repeat failed cases with XPIsland alone.

| Check | Steps | Expected result / evidence |
| --- | --- | --- |
| Named kill rewards and locale | Select Experience and Kills to level. Run `/xpisland reset` on the test character. Kill five XP-bearing mobs, recording each combat-XP chat line and player XP before/after. Include a rested kill and a group kill; repeat in a party dungeon and each locale being claimed as tested. | First four confirmed kills show a dash; five comparable rewards produce `ceil(remaining XP / mean reward)` kills. A bonus printed in the chat line is not added a second time. Dungeon rewards remain Dungeon XP. Session categories sum to total XP. Save exact localized strings if a kill is not recognized. |
| Event order and changing rewards | Gain kill XP across a level-up, then enter/leave a dungeon with a loading screen. Change group size and consume the remaining rested pool. If a result disagrees with the recorded rewards, capture the relevant `CHAT_MSG_COMBAT_XP_GAIN`, `PLAYER_XP_UPDATE`, `PLAYER_LEVEL_UP` and loading events using the event trace. | Each confirmed kill counts once; loading does not fabricate a kill. Existing history survives ordinary context changes; estimates adapt to new rewards rather than resetting. The estimate is not a forecast of rested exhaustion. |
| History lifecycle | With a populated estimate, reload; reconnect within five minutes; then use `/xpisland reset`. Separately leave the character online without kills for over 61 minutes. | Reload/reconnect retain valid history and exclude offline time. Explicit reset clears it. Expired history shows a dash and an explanatory tooltip, not zero/infinity. |
| Pet identity and XP | On a character with a leveling pet, compare the footer tooltip to the native pet XP display. Gain pet XP, level the pet, dismiss/resummon, swap pets and cross a loading screen. Repeat a swap while hovering the pet detail. | Current pet name, level and XP agree with native UI. Missing/non-leveling pets have no row. Old pet names/tooltips do not survive replacement. Other XP values are unaffected. |
| Honor and rank | Select Honor & PvP. Compare Honor available with the native currency balance and rank/Rank Points with Character → PvP. Earn rewards, spend Honor, then inspect a weekly cap or seasonal maximum on a suitable character. If no such character is available, leave those subcases unrun. | Spending reduces available Honor only. Rank progress and cumulative current ceiling match native UI. Valid zero is shown as zero; unavailable data is a dash. Cap/maximum states stay visible. Test season rollover when available; do not simulate it and call it live coverage. |
| Mode and cap transitions | Toggle modes with the drawer open, a tooltip visible and an animation in progress. Enable automatic switching on a character about to reach the actual level cap. Separately disable XP below cap. | Mode changes collapse and clear transient UI without resetting the XP session. Automatic switching uses the actual cap; disabling XP below cap does not select PvP. Combat collapse does not reopen automatically on exit. |
| Native controls and readability | Open Tracking via `/xpisland`. Use each native dropdown with keyboard navigation and selection; use Escape to dismiss it and the options window. Set and exercise the expansion keybinding. Test supported fonts/sizes, scale 50–150%, top/bottom/custom placement and the actual notch/external-display setup. Hover all footer fields, cross between them, and disable a field with its tooltip pending. | Menus select/dismiss correctly; the binding toggles the island. Labels, numbers and hit regions remain legible and reachable. Tooltip delay is about 750 ms, with no stale tooltip after hiding, mode changes or combat. Record screenshots at any clipping/overlap. Custom option tabs and stat tooltips are not claimed to provide complete keyboard-only accessibility. |
| Restricted values, combat and coexistence | With XPIsland alone, inspect progression during combat and an actual battleground. Repeat with Ellesmere stock bars, then its custom data bars, and watched reputation. Toggle Hide Blizzard XP outside combat and request a change during combat. Use the normal taint/error logging setup; retain logs for blocked actions. | No restricted-value or blocked-action errors. Only stock XP is suppressed when XPIsland owns that policy; reputation/Honor remain available. Combat defers stock-bar changes until exit. Ellesmere custom-bar ownership is respected. A mock sentinel is not proof of this result. |

Record each result as `PASS`, `FAIL`, or `NOT RUN`, with commit/build/locale,
steps, actual versus expected output, and screenshots or error/event logs when
relevant. Weekly/seasonal and hardware-specific checks can remain explicitly
pending. Restore temporary debugging settings and test-only keybindings afterward.

For a discrepancy, first preserve the evidence; do not edit SavedVariables or
reset again before recording it. The offline counterparts are
`tests/progression_events_test.lua`, `tests/progression_test.lua`,
`tests/kills_test.lua`, `tests/tooltip_test.lua`, and `tests/stock_tracking_test.lua`.

# XPIsland

A standalone experience capsule for **official World of Warcraft: Forever**. Version 0.5.2 targets interface 16001 and was checked against Blizzard UI source for 1.60.1.70205. Retail, Classic Era, and other clients are not supported.

## Install

1. Extract the release ZIP so the folder is `Interface/AddOns/XPIsland/` and contains `XPIsland.toc` directly.
2. On this Mac the destination is `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/XPIsland/`.
3. Fully restart WoW after adding the folder for the first time. Subsequent file updates can normally use `/reload`.
4. Enable XPIsland in the AddOns list. Type `/xpisland` to open its settings.

No other addon is required. Existing addon files and settings do not need modification. To uninstall, remove only the `XPIsland` addon folder while the game is closed. Its saved settings may remain in WoW's SavedVariables files unless you separately choose to remove them.

## Use

- Click the capsule or its expanded cells to expand/collapse. Configure **Expand / collapse XPIsland** in WoW Keybindings, accessible from XPIsland's Options page. No key is claimed by default.
- Twenty segments show exact level progress with a partially filled final segment. The right label defaults to earned percentage. Alternatives are Current / Total XP, XP Remaining, XP Remaining (%), and Time to Next Level.
- The bar hover shows exact current/total XP with the client’s number grouping and earned percentage. A short expand hint appears only until the first deliberate expansion by click, keybinding or settings. `XPIslandDB.expandedOnce` persists account-wide across reload/login, character changes and profile copies; automatic level-up previews do not dismiss it.
- Normal XP is purple, rested XP blue. Color pickers preview changes and support cancel. The rested cell shows the remaining rested pool, including any amount beyond this level, or a dash.
- Auto-collapse is enabled by default with a 15-second interval. Its adjacent slider offers 5, 10 or 15 seconds. The capsule remains visible. Hovering the island, dragging it, or keeping its settings open suspends the timeout; leaving restarts the full interval. Pointer events react immediately, with the existing one-second ticker reconciling child-frame/geometry changes.
- A level-up opens a preview when enabled, even if ordinary auto-collapse is disabled. Its slider offers 5, 10 or 15 seconds, defaulting to 10. Repeated level-ups restart the selected interval. Manual toggling takes over: closing cancels the timer; opening uses the auto-collapse slider. Profile/settings changes preserve which action opened the island and apply that action's configured interval. Hover/settings/dragging suspend the level-up collapse timeout too.
- Collapse when combat starts is enabled by default. Combat entry cancels the pending timeout and closes the details, even while hovered or configuring. Combat exit never reopens them. Automatic level-up opening is suppressed during combat with this option on; an explicit manual toggle remains available. Hiding at cap cancels animation and timeout, and returning starts collapsed. These toggles default on for existing profiles without changing saved false values.
- The island is locked initially. Top is the default position and expands down; Bottom expands up. Unlock it to drag to a Custom position, which expands into the side with more space. Reset to top restores the default. It hides at the client's effective XP cap or when XP is disabled. Cap visibility takes precedence over the level-up expansion.
- `/xpisland reset` explicitly starts a fresh session. There is no pause control.

## Responsive sizing

The default is bounded, not a percentage of an ultrawide screen. The following are **UIParent logical units**, not physical pixels or 3D render resolution:

| Usable UIParent width | Collapsed | Expanded |
| --- | ---: | ---: |
| Below 1400 | 360 × 34 | 460 × ≥141 |
| 1400–1999 | 400 × 34 | 520 × ≥141 |
| 2000 and above | 440 × 34 | 560 × ≥141 |

Expanded height starts at 141 units and grows when the selected font needs more room. The drawer measures the text block, centers each row, and uses equal 12-unit top/bottom insets with a 6-unit row gap. The source row includes five units for a three-unit gap and a two-unit share fill beneath each value.

The independent island scale defaults to 100%. Its slider and numeric field both accept 50–150%. These multiply WoW's effective UI scale; maximum unscaled widths remain 440/560 even on larger screens. A final fit-to-screen limit keeps the expanded panel inside the available viewport. The collapsed width may grow within its 440-unit maximum for a wide custom font. Labels use unbounded text measurements and compact K/M numbers. A useful bar width is preserved without shrinking the selected text size. The header keeps its vertical position and horizontal centre while its width grows with the island. Segments fill the available header width and the measured label stays 14 units from its right edge. The two rows of four stat cells have centred labels/values and equal 20-unit outer margins. Custom anchors reserve the complete expanded footprint even while collapsed. Global WoW UI scale and graphics settings are never changed.

The anchor is eight UIParent units below the top edge. WoW already shifts UIParent for the Mac **Notched Display Mode → Shift UI** option. XPIsland inherits that position and adds no second notch offset. It also follows display/UI scale changes. When WoW is configured to overlap the notch, XPIsland respects that choice; drag it lower if desired.

Expansion and contraction use a short normalized critically damped curve (220 ms for the full distance; at least 80 ms for an interrupted short distance). Reversals start from the current shape, and numeric-label remeasurement preserves transition progress. Details fade with progress inside a clipped region. Tooltip hit regions activate only when fully open. The temporary OnUpdate script is removed on completion, hiding, dragging or profile/layout replacement; there is no idle animation work.

The island uses HIGH strata at level 100, above ordinary action bars/panels. Its children inherit this layer; DIALOG settings/system prompts and native menus/tooltips retain their higher ordering. It does not continually raise itself over other addons.

## XP accounting

The first row shows remaining/total level XP, rolling XP/hour, estimated time to the next level, and rested XP. XP/hour uses the rolling model below. ETA is remaining XP divided by its unrounded effective rate. ETA remains unavailable for the first minute, at zero rate, at the cap, or while rebuilding pace after an uncountable change; zero XP/hour is shown as 0. Time displays use minutes (26m, 1h 42m), not a second countdown. The ETA stat tooltip adds expanded duration, rate and exact remaining XP when available. The collapsed ETA label uses an infinity mark only for a session with no XP activity or an expired rolling rate. This means no estimable current rate, not a promise of infinite leveling time. It uses a bundled symbol so custom font glyph coverage cannot break it; texture-load failure falls back to `n/a`. Warmup or pace recovery keeps a dash. Hover distinguishes no session activity, first-minute history collection, prior XP outside the rate window, and temporary pace recovery, followed by exact current/total level XP (%).

The second row consists of mutually exclusive session XP totals, in this order:

1. **Kill XP:** confirmed named kill messages outside instances, including rested/group bonuses already present in the earned XP amount.
2. **Quest XP:** confirmed quest rewards received outside instances. Turning in a dungeon quest outdoors belongs here.
3. **Dungeon XP:** every XP gain received inside a party dungeon, including kills, quests, exploration, and unidentified bonuses.
4. **Other XP:** exploration, raid/other-instance gains, and sources that cannot be confirmed.

`UnitXP`/`UnitXPMax` deltas determine the total. Quest and localized kill-message events only classify XP already observed; they never independently increase it. A bounded two-second reconciliation queue tolerates notification order and combined updates. Dungeon context takes precedence. Chat line IDs prevent duplicate kill messages from being reused. Unnamed, unreadable, expired, and mismatched source hints remain Other. Attribution is best effort because the client does not provide a universal transaction ID linking every XP update to its source.

A normal level rollover adds the old level's remaining XP plus the new level's XP. Unit reads wait through loading and inconsistent level/cap values briefly settle before being accepted. If multiple levels are skipped without observable thresholds, or a backward correction is confirmed, recorded totals remain and only rolling history restarts instead of estimating missing gains. The temporary ETA tooltip says “Recalculating your leveling pace”; estimates resume after the normal minute of fresh history with XP. Source-total tooltips identify recorded-only totals when needed. Profile changes do not reset accounting.

## Rolling XP rate

Displayed source totals remain session totals. The rate uses online session age A, including online idle, running, travel and loading screens, and excluding reload/disconnected time. K20 and K60 are confirmed kill XP over the last 20 and 60 online minutes; N60 is all non-kill XP over the last hour. The effective rate in XP/second is:

```
T20 = min(1200, max(A, 60))
T60 = min(3600, max(A, 60))
R = N60/T60 + 0.5*K60/T60 + 0.5*K20/T20
XP/hour = 3600*R
ETA = XP remaining / R
```

Before 20 minutes this naturally uses the available session average with a one-minute denominator floor. Afterwards, recent kill XP responds faster to changes in grinding pace. Both rising and falling kill pace use the same weighting. A mature 6,000 XP quest burst contributes 6,000 XP/hour while fully inside the hour, not 18,000; an early-session burst can still give an optimistic estimate. There is no adaptive reset or burst detector.

Sixty-one rotating one-minute buckets store total and confirmed kill XP. The current bucket counts fully; the oldest partly overlapping bucket is prorated. This is minute-level approximation, not event timestamps. Unknown sources get no kill boost. Confirmed dungeon kills count toward the internal kill weighting while appearing only in Dungeon XP; dungeon quest rewards are non-kill XP. Late source reconciliation corrects the original award bucket without increasing total XP.

History survives valid reload/grace restoration and resets with the session. A pre-0.2 saved session has no reconstructable timeline: its session totals are preserved while rate history begins afresh, with a new one-minute ETA warmup. No offline period is inserted into rate history. Durations of 999 days or more display 999d+; extremely large numeric totals use 999M+ instead of producing unbounded labels. K/M suffixes are concise English abbreviations; the decimal separator follows the client locale.

## Session lifetime

Sessions belong to a character, independently of settings profiles. Connected session time includes idle, running, Hearthstones, zoning and dungeon loading screens. Loading is gameplay downtime and never starts a new session or invalidates an estimate. XP reads wait while unit data is unavailable, while elapsed time continues. Reload and actual detected disconnected intervals remain excluded.

- `/reload` resumes the session without counting reload downtime. Old 0.3/0.4 sessions carrying the permanent incomplete flag preserve recorded counters, clear that veto and rebuild only the rolling pace history once.
- An unintentional departure with a valid saved snapshot resumes on the same character within 300 seconds. A longer absence starts fresh.
- Observed deliberate logout/quit ends the session. Cancelling logout preserves it. `PLAYER_LOGOUT` alone is not treated as proof of deliberate logout.
- Server time checks reconnect eligibility. Accumulated monotonic time determines XP/hour; offline wall-clock duration is never added.
- Crash/force-quit recovery is best effort. WoW controls when SavedVariables reach disk; addons cannot force heartbeat snapshots to disk. A stale reload snapshot, invalid counters, or wrong-character snapshot is rejected. The exact point a network failure becomes observable also limits disconnect timing precision.

## Options and profiles

`/xpisland` opens one Options page and one Profiles page in a restrained dark panel with thin grouped borders, small tabs, 12-point labels, colour swatches and compact action buttons. The native dropdown selected-text box is anchored left/right, vertically centered in the full 24-unit control, and bounded before the arrow; it does not inherit the Classic template’s 10-unit TOP anchors. Native WowStyle1DropdownTemplate menus supply radio selections, dismissal, keyboard behavior and scrolling; native checkboxes, input fields and slider retain familiar controls. Settings are 620 × 462 UI units and fit smaller viewports without changing the island scale. Game Tooltip (default) reads the current tooltip body font without modifying it. For an unskinned roman client this is Friz Quadrata; other locales and installed tooltip skins may supply another face. Default island text is 14, with 12-point headings and a subtle shadow instead of a heavy outline. The user can explicitly choose Arial, Friz Quadrata, or a registered LibSharedMedia font. A missing external font falls back to the current tooltip face. The selected face also applies to settings.

Settings schema 2 migrates unmarked Arial/12 defaults to the new face/size while preserving other choices and dragged positions. Version 0.1 did not record whether selecting Arial/12 was intentional, so that ambiguous old-default case follows the new default. Explicit choices are recorded from this version onward. Profile copies preserve those choices.

**Shared** is the account-wide default. Changes affect every character selecting it. **Use character** creates an independent copy for the current character. **Duplicate and use** creates a named copy. **Copy settings** overwrites the current profile only after a second confirmation click. Session totals and WoW keybindings are not copied with a profile.

## Optional Blizzard XP hiding

Coexistence is the default. **Hide Blizzard XP bar** filters only the Experience entry on the stock tracking manager, preserving reputation and other tracking categories and allowing normal layout. Enabling/disabling waits until combat ends. Disabling restores XPIsland's own filter without overwriting a newer owner.

Ellesmere's custom data-bar mode is left alone. Its own XP bar must be controlled through Ellesmere. XPIsland does not hide the shared manager, unregister its events, mutate another addon's profiles, or try to re-show bars another addon owns. This optional integration uses Blizzard UI implementation details and still requires live combat/Edit Mode verification on the target client.

## Validation status

See [validation coverage](VALIDATION.md) for exact checks. LuaJIT model and mocked-runtime tests exercise the implementation; generated SVG/PNG previews are offline layout fixtures, **not in-game screenshots**. Live network disconnects, event ordering, localized combat messages, combat taint, Edit Mode, and physical Mac notch behavior require in-game acceptance testing.

## Source references

- [Matching Blizzard UI snapshot](https://github.com/Gethe/wow-ui-source/tree/e3ecc27b64d30fdc735a3f6579b866858f9f9df1)
- [XP and level events](https://github.com/Gethe/wow-ui-source/blob/e3ecc27b64d30fdc735a3f6579b866858f9f9df1/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [Mac UIParent positioning](https://github.com/Gethe/wow-ui-source/blob/e3ecc27b64d30fdc735a3f6579b866858f9f9df1/Interface/AddOns/Blizzard_UIParentUtil/UIParentUtil.lua)
- [Stock XP eligibility](https://github.com/Gethe/wow-ui-source/blob/e3ecc27b64d30fdc735a3f6579b866858f9f9df1/Interface/AddOns/Blizzard_StatusTrackingBar/Mainline/StatusTrackingManagerOverrides.lua)

XPIsland's code and rounded textures are original. No Ellesmere/Danders code, fonts, or artwork is bundled.

Expanded stat tooltips require 750 milliseconds over the same cell. Leaving, switching cells, collapsing, hiding or dragging cancels that hover; the next cell starts a fresh delay. The collapsed bar keeps its immediate tooltip.


## Progress details in 0.5

Newly completed 5% segments receive one subtle white highlight fading out over 250 ms. Multiple segments completed by the same gain highlight together. Only accepted positive XP gains within the same level trigger it; login, loading restoration, repainting, profile changes, rested changes and rollover do not. The highlight has a temporary animation callback and stops on completion, hiding, dragging, loading, reset or profile relayout.

The solid earned bar remains blue while rested XP is available and purple otherwise, using the configured colors. A muted version of the rested color previews progress from current XP to current XP plus remaining rested XP, capped at the current level. It preserves segment gaps and rounded end caps. The Rested XP number still includes overflow into later levels. The preview is a rested allowance, not XP already earned or a prediction about future rewards.

The four source values have thin proportional fills. Each uses its category divided by total recorded session XP, so dungeon XP remains mutually exclusive with outdoor kills and quests. Late attribution corrections move the appropriate shares without changing total XP. A zero-XP session has neutral empty tracks, not invented percentages. No new numbers, rows or settings are added.

During the existing level-up expansion, a known completed-level duration replaces the header's entire XP bar and right label with “Last level took 1h 42m” (or “Last level took 36m”). The existing Time to Level cell and its tooltip keep showing live ETA. The header message uses the selected font, scales to fit the pill, adds no row, and restores the XP bar after the configured level-up interval (10 seconds by default), even while hovering. Collapse, combat dismissal and hiding cancel it; cap and level-up preference rules still apply. A delayed reply must arrive during the original level-up presentation window to display. Once displayed it gets the selected level-up interval and the collapse deadline follows that interval; it cannot reopen a dismissed island.

### Authoritative played time (0.5.1)

`RequestTimePlayed()` returns `TIME_PLAYED_MSG(totalTimePlayed, timePlayedThisLevel)`. Their difference is the current level's start on the game's lifetime-played-time axis. Subtracting adjacent level-start anchors gives the completed level's full duration, including time played before XPIsland loaded. XPIsland stores only a version, character GUID and current `{level, start, total}` anchor in per-character `XPIslandPlayed`. It does not track another per-level clock, reconstruct wall time or extrapolate a partial duration. AFK and offline accounting follow WoW's counters. Session XP/hour has its separate existing clock and reset behavior.

Snapshots occur at login/reload, detected reconnection and level changes, using the existing ticker, one in-flight request, an eight-second timeout and at most three attempts per synchronization. Ordinary zoning invalidates an outstanding request but does not request additional snapshots when already synchronized. Valid snapshots require stable readable level data, finite integer counters, monotonic total played, a consistent same-level anchor and a positive adjacent-level interval. Duplicate events do not restart requests or presentation. Skipped levels cannot supply a missing intermediate start.

Saved anchors are independent of profiles and session resets. Reload, ordinary logout, long reconnection and crashes do not inherently invalidate a saved anchor. WoW controls when SavedVariables reach disk: an unsaved anchor lost in a crash is unavailable. A login snapshot midway through a level still establishes its full server-recorded start, so the next completion can be measured. Old installs without this new variable begin with that snapshot. No live SavedVariables files are edited.

The event supplies no request ID, level number or native silent flag. Invalidated requests drain before replacements. Overlap or timeout requires two matching authoritative anchors before a new baseline is trusted; known previous anchors reject stale old-level replies. Arbitrarily reordered concurrent responses cannot be perfectly correlated. Genuinely missing or ambiguous data omits the notice instead of reporting partial elapsed time as complete.

For normally owned replies, XPIsland temporarily composes normal chat frames' Blizzard `customEventHandler` extension. Existing handlers run first; only XPIsland's owned `TIME_PLAYED_MSG` is consumed. Restoration is deferred through the event dispatch and only touches fields still owned by XPIsland. A secure post-hook observes external `RequestTimePlayed` calls and immediately disables suppression. Known outstanding replies drain before quiet synchronization resumes. After a timeout, ownership cannot be proved, so further automatic replies remain visible for that UI session. There are no global chat-function replacements, event unregisters or native API replacements. Newly created chat windows and unusual dispatch behavior fail open; live-client coexistence remains an acceptance check.

Primary API/source evidence: [RequestTimePlayed](https://github.com/Gethe/wow-ui-source/blob/e3ecc27b64d30fdc735a3f6579b866858f9f9df1/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerScriptDocumentation.lua), [TIME_PLAYED_MSG](https://github.com/Gethe/wow-ui-source/blob/e3ecc27b64d30fdc735a3f6579b866858f9f9df1/Interface/AddOns/Blizzard_APIDocumentationGenerated/SystemDocumentation.lua), [chat dispatch extension](https://github.com/Gethe/wow-ui-source/blob/e3ecc27b64d30fdc735a3f6579b866858f9f9df1/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrame.lua#L3), and [Blizzard's use of that extension](https://github.com/Gethe/wow-ui-source/blob/e3ecc27b64d30fdc735a3f6579b866858f9f9df1/Interface/AddOns/Blizzard_ChatFrame/Shared/VoiceChatTranscriptionFrame.lua#L183). These are the matching Forever 1.60.1.70205 snapshot, commit `e3ecc27b64d30fdc735a3f6579b866858f9f9df1`.

### Duration controls (0.5.2)

Two native `UISliderTemplate` controls sit in the existing Behavior rows. Each snaps to 5, 10 or 15 seconds, shows the current value with `s`, and dims/disables with its related toggle. Reduced checkbox and slider hit rectangles keep those controls and neighboring rows separate. Settings typography and panel dimensions are unchanged. `levelUpDuration` and `autoCollapseDuration` are optional profile fields normalized to their existing 10/15 defaults when missing or invalid; valid values survive switching, copying, character profiles and reload. No manual SavedVariables migration is needed.

Changing a duration reconciles its active timers. A header notice retains its original display start: shortening below elapsed time expires it immediately, and unrelated appearance changes cannot restart it. Canceled callbacks cannot expire a newer timer. Hover still restarts a full collapse interval on departure; it does not pause header expiry. Disabling level-up presentation clears its notice; disabling manual auto-collapse removes that timeout without changing the level-up policy. The per-cell tooltip delay stays 750 ms.

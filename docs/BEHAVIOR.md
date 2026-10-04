# XPIsland

A standalone experience capsule for **official World of Warcraft: Forever**. Version 0.2.0 targets interface 16001 and was checked against Blizzard UI source for 1.60.1.70205. Retail, Classic Era, and other clients are not supported.

## Install

1. Extract the release ZIP so the folder is `Interface/AddOns/XPIsland/` and contains `XPIsland.toc` directly.
2. On this Mac the destination is `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/XPIsland/`.
3. Fully restart WoW after adding the folder for the first time. Subsequent file updates can normally use `/reload`.
4. Enable XPIsland in the AddOns list. Type `/xpisland` to open its settings.

No other addon is required. Existing addon files and settings do not need modification. To uninstall, remove only the `XPIsland` addon folder while the game is closed. Its saved settings may remain in WoW's SavedVariables files unless you separately choose to remove them.

## Use

- Click the capsule or its expanded cells to expand/collapse. Configure **Expand / collapse XPIsland** in WoW Keybindings, accessible from XPIsland's Options page. No key is claimed by default.
- Twenty segments show exact level progress with a partially filled final segment. The right label defaults to earned percentage. Alternatives are Current / Total XP, XP Remaining, XP Remaining (%), and Time to Next Level.
- Normal XP is purple, rested XP blue. Color pickers preview changes and support cancel. The rested cell shows the remaining rested pool, including any amount beyond this level, or a dash.
- A level-up expands the capsule for ten seconds. Clicking, changing settings, or dragging cancels the automatic collapse. The checkbox disables automatic expansion.
- The island is locked initially. Top is the default position and expands down; Bottom expands up. Unlock it to drag to a Custom position, which expands into the side with more space. Reset to top restores the default. It hides at the client's effective XP cap or when XP is disabled. Cap visibility takes precedence over the level-up expansion.
- `/xpisland reset` explicitly starts a fresh session. There is no pause control.

## Responsive sizing

The default is bounded, not a percentage of an ultrawide screen. The following are **UIParent logical units**, not physical pixels or 3D render resolution:

| Usable UIParent width | Collapsed | Expanded |
| --- | ---: | ---: |
| Below 1400 | 360 × 34 | 460 × 144 |
| 1400–1999 | 400 × 34 | 520 × 144 |
| 2000 and above | 440 × 34 | 560 × 144 |

The independent island scale defaults to 100%. Its slider and numeric field both accept 50–150%. These multiply WoW's effective UI scale; maximum unscaled widths remain 440/560 even on larger screens. A final fit-to-screen limit keeps the expanded panel inside the available viewport. The collapsed width may grow within its 440-unit maximum for a wide custom font. Labels use unbounded text measurements and compact K/M numbers. A useful bar width is preserved without shrinking the selected text size. The bar stays fixed while the surrounding details expand. Custom anchors reserve the complete expanded footprint even while collapsed. Global WoW UI scale and graphics settings are never changed.

The anchor is eight UIParent units below the top edge. WoW already shifts UIParent for the Mac **Notched Display Mode → Shift UI** option. XPIsland inherits that position and adds no second notch offset. It also follows display/UI scale changes. When WoW is configured to overlap the notch, XPIsland respects that choice; drag it lower if desired.

## XP accounting

The first row shows remaining/total level XP, rolling XP/hour, estimated time to the next level, and rested XP. XP/hour uses the rolling model below. ETA is remaining XP divided by its unrounded effective rate. ETA remains unavailable for the first minute, at zero rate, at the cap, or after an unrecoverable accounting gap; zero XP/hour is shown as 0. Time displays use minutes (26m, 1h 42m), not a second countdown. The ETA tooltip adds expanded duration, rate and exact remaining XP.

The second row consists of mutually exclusive session XP totals, in this order:

1. **Kill XP:** confirmed named kill messages outside instances, including rested/group bonuses already present in the earned XP amount.
2. **Quest XP:** confirmed quest rewards received outside instances. Turning in a dungeon quest outdoors belongs here.
3. **Dungeon XP:** every XP gain received inside a party dungeon, including kills, quests, exploration, and unidentified bonuses.
4. **Other XP:** exploration, raid/other-instance gains, and sources that cannot be confirmed.

`UnitXP`/`UnitXPMax` deltas determine the total. Quest and localized kill-message events only classify XP already observed; they never independently increase it. A bounded two-second reconciliation queue tolerates notification order and combined updates. Dungeon context takes precedence. Chat line IDs prevent duplicate kill messages from being reused. Unnamed, unreadable, expired, and mismatched source hints remain Other. Attribution is best effort because the client does not provide a universal transaction ID linking every XP update to its source.

A normal level rollover adds the old level's remaining XP plus the new level's XP. If multiple levels are skipped without observable thresholds, or XP is corrected backwards, the session is marked incomplete instead of estimating missing gains. Its tooltip explains why rate/ETA are unavailable. Profile changes do not reset accounting.

## Rolling XP rate

Displayed source totals remain session totals. The rate uses online session age A, including online idle and excluding loading/reload/disconnected gaps. K20 and K60 are confirmed kill XP over the last 20 and 60 online minutes; N60 is all non-kill XP over the last hour. The effective rate in XP/second is:

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

Sessions belong to a character, independently of settings profiles. Connected in-world time, including idle time, counts. Loading/reload and detected disconnected intervals do not.

- `/reload` resumes the session without counting reload downtime.
- An unintentional departure with a valid saved snapshot resumes on the same character within 300 seconds. A longer absence starts fresh.
- Observed deliberate logout/quit ends the session. Cancelling logout preserves it. `PLAYER_LOGOUT` alone is not treated as proof of deliberate logout.
- Server time checks reconnect eligibility. Accumulated monotonic time determines XP/hour; offline wall-clock duration is never added.
- Crash/force-quit recovery is best effort. WoW controls when SavedVariables reach disk; addons cannot force heartbeat snapshots to disk. A stale reload snapshot, invalid counters, or wrong-character snapshot is rejected. The exact point a network failure becomes observable also limits disconnect timing precision.

## Options and profiles

`/xpisland` opens one Options page and one Profiles page using Blizzard's native frame, buttons, checkboxes, input fields and slider. Game Tooltip (default) reads the current tooltip body font without modifying it. For an unskinned roman client this is Friz Quadrata; other locales and installed tooltip skins may supply another face. Default island text is 14, with 12-point headings and a subtle shadow instead of a heavy outline. The user can explicitly choose Arial, Friz Quadrata, or a registered LibSharedMedia font. A missing external font falls back to the current tooltip face. The selected face also applies to settings.

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

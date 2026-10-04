# XPIsland

A standalone experience capsule for **official World of Warcraft: Forever**. Version 0.1.0 targets interface 16001 and was checked against Blizzard UI source for 1.60.1.70205. Retail, Classic Era, and other clients are not supported.

## Install

1. Extract the release ZIP so the folder is `Interface/AddOns/XPIsland/` and contains `XPIsland.toc` directly.
2. On this Mac the destination is `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/XPIsland/`.
3. Fully restart WoW after adding the folder for the first time. Subsequent file updates can normally use `/reload`.
4. Enable XPIsland in the AddOns list. Type `/xpisland` to open its settings.

No other addon is required. Existing addon files and settings do not need modification. To uninstall, remove only the `XPIsland` addon folder while the game is closed. Its saved settings may remain in WoW's SavedVariables files unless you separately choose to remove them.

## Use

- Click the capsule or its expanded cells to expand/collapse. Configure **Expand / collapse XPIsland** in WoW Keybindings, accessible from XPIsland's Options page. No key is claimed by default.
- Twenty segments show exact level progress with a partially filled final segment. The right label defaults to earned percentage. Alternatives are earned/total, XP left, and XP left with remaining percentage.
- Normal XP is purple, rested XP blue. Color pickers preview changes and support cancel. The rested cell shows the remaining rested pool, including any amount beyond this level, or a dash.
- A level-up expands the capsule for ten seconds. Clicking, changing settings, or dragging cancels the automatic collapse. The checkbox disables automatic expansion.
- The island is locked initially. Unlock it in Options to drag it; Reset position returns it to the top center. It hides at the client's effective XP cap or when XP is disabled. Cap visibility takes precedence over the level-up expansion.
- `/xpisland reset` explicitly starts a fresh session. There is no pause control.

## Responsive sizing

The default is bounded, not a percentage of an ultrawide screen. The following are **UIParent logical units**, not physical pixels or 3D render resolution:

| Usable UIParent width | Collapsed | Expanded |
| --- | ---: | ---: |
| Below 1400 | 360 × 30 | 460 × 124 |
| 1400–1999 | 400 × 30 | 520 × 124 |
| 2000 and above | 440 × 30 | 560 × 124 |

The independent island scale defaults to 100%. Its slider and numeric field both accept 50–150%. These multiply WoW's effective UI scale; maximum unscaled widths remain 440/560 even on larger screens. A final fit-to-screen limit keeps the expanded panel inside the available viewport. Large cell values reduce font size only as needed to fit. Global WoW UI scale and graphics settings are never changed.

The anchor is eight UIParent units below the top edge. WoW already shifts UIParent for the Mac **Notched Display Mode → Shift UI** option. XPIsland inherits that position and adds no second notch offset. It also follows display/UI scale changes. When WoW is configured to overlap the notch, XPIsland respects that choice; drag it lower if desired.

## XP accounting

The first row shows remaining/total level XP, session XP/hour, estimated time to the next level, and rested XP. Rate/ETA remain unavailable for the first minute, with no earned XP, or after an unrecoverable accounting gap.

The second row consists of mutually exclusive session XP totals, in this order:

1. **Outdoor kills:** confirmed named kill messages outside instances, including rested/group bonuses already present in the earned XP amount.
2. **Outdoor quests:** confirmed quest rewards received outside instances. Turning in a dungeon quest outdoors belongs here.
3. **Dungeons:** every XP gain received inside a party dungeon, including kills, quests, exploration, and unidentified bonuses.
4. **Other:** exploration, raid/other-instance gains, and sources that cannot be confirmed.

`UnitXP`/`UnitXPMax` deltas determine the total. Quest and localized kill-message events only classify XP already observed; they never independently increase it. A bounded two-second reconciliation queue tolerates notification order and combined updates. Dungeon context takes precedence. Chat line IDs prevent duplicate kill messages from being reused. Unnamed, unreadable, expired, and mismatched source hints remain Other. Attribution is best effort because the client does not provide a universal transaction ID linking every XP update to its source.

A normal level rollover adds the old level's remaining XP plus the new level's XP. If multiple levels are skipped without observable thresholds, or XP is corrected backwards, the session is marked incomplete instead of estimating missing gains. Its tooltip explains why rate/ETA are unavailable. Profile changes do not reset accounting.

## Session lifetime

Sessions belong to a character, independently of settings profiles. Connected in-world time, including idle time, counts. Loading/reload and detected disconnected intervals do not.

- `/reload` resumes the session without counting reload downtime.
- An unintentional departure with a valid saved snapshot resumes on the same character within 300 seconds. A longer absence starts fresh.
- Observed deliberate logout/quit ends the session. Cancelling logout preserves it. `PLAYER_LOGOUT` alone is not treated as proof of deliberate logout.
- Server time checks reconnect eligibility. Accumulated monotonic time determines XP/hour; offline wall-clock duration is never added.
- Crash/force-quit recovery is best effort. WoW controls when SavedVariables reach disk; addons cannot force heartbeat snapshots to disk. A stale reload snapshot, invalid counters, or wrong-character snapshot is rejected. The exact point a network failure becomes observable also limits disconnect timing precision.

## Options and profiles

`/xpisland` opens one Options page and one Profiles page. Choose built-in Arial or Friz Quadrata, plus fonts registered by LibSharedMedia when available. Fonts are referenced, not copied from other addons. A missing external font falls back to Arial. The selected font face also applies to XPIsland's settings window.

**Shared** is the account-wide default. Changes affect every character selecting it. **Per-character** creates an independent copy for the current character. **Duplicate & switch** creates a named copy. **Copy settings** overwrites the current profile only after a second confirmation click. Session totals and WoW keybindings are not copied with a profile.

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

XPIsland's code and rounded texture are original. No Ellesmere/Danders code, fonts, or artwork is bundled.

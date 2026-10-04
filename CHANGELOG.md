# Changelog

## 0.5.1

XPIsland 0.5.1 for World of Warcraft: Forever 1.60.1 only.

- “Last level took 1h 42m” (or “Last level took 36m”) replaces the XP bar and its label in the header pill for ten seconds, then restores them. Time to Level keeps showing live ETA throughout. The message fits the selected font without adding a row.
- Completed-level duration now comes from the game's authoritative `/played` counters. A small per-character level-start anchor survives reloads, reconnects and session resets. AFK counts according to WoW; no addon elapsed clock or offline wall-time estimate is used for this duration.
- Automatic snapshots synchronize at login, reconnection and level changes, with at most three attempts per synchronization. Normally owned replies are quiet; overlapping manual requests remain visible. After a timeout, automatic replies also remain visible because the API supplies no request ID.
- Delayed replies cannot reopen a dismissed notice. Duplicate level events, combat, cap, preferences and repeated level-ups preserve cleanup and header restoration.

A missing saved level-start anchor or genuinely ambiguous response can still prevent a completed-level duration. WoW controls SavedVariables disk writes, so an anchor not yet saved before a crash cannot be recovered. The next login snapshot can establish the current level's complete start time even midway through the level. In-game network ordering and native chat integration still require acceptance after reload.

## 0.5.0

XPIsland 0.5.0 for World of Warcraft: Forever 1.60.1 only.

- Newly completed XP segments briefly brighten for 250 ms. Large gains highlight completed segments together, without pulses on login, repainting or level rollover.
- A muted rested XP preview extends ahead of earned XP while keeping the segment gaps. It stops at this level's end; the rested number still includes any overflow. Your configured rested color applies to the preview.
- Thin fills under Kill, Quest, Dungeon and Other XP show each source's share of session XP, without extra numbers or rows.
- Level-up expansion can show “Last level took 1h 42m” (or “Last level took 36m”) in the ETA cell for ten seconds, then restores Time to Level. It appears only for a whole level observed continuously; initial partial levels, reloads, disconnections and uncertain boundaries are omitted. Session resets and profile changes do not reset level timing. No automatic /played requests or chat hooks are used.

The 750 ms tooltip delay, combat/cap behavior and existing session accounting remain intact. Expanded height grows by five UI units to keep source fills clear of text. Independent reviews and regression tests cover each feature, event ordering, layout bounds and temporary animation/timer cleanup. Native rendering and live event behavior still need in-game acceptance after reload.

## Earlier releases

See [release notes](https://github.com/elithrar/XPIsland/releases) for 0.4.3 and earlier.

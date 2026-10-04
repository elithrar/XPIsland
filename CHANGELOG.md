# Changelog

## 0.5.0

XPIsland 0.5.0 for World of Warcraft: Forever 1.60.1 only.

- Newly completed XP segments briefly brighten for 250 ms. Large gains highlight completed segments together, without pulses on login, repainting or level rollover.
- A muted rested XP preview extends ahead of earned XP while keeping the segment gaps. It stops at this level's end; the rested number still includes any overflow. Your configured rested color applies to the preview.
- Thin fills under Kill, Quest, Dungeon and Other XP show each source's share of session XP, without extra numbers or rows.
- Level-up expansion can show “Last level took 1h 42m” (or “Last level took 36m”) in the ETA cell for ten seconds, then restores Time to Level. It appears only for a whole level observed continuously; initial partial levels, reloads, disconnections and uncertain boundaries are omitted. Session resets and profile changes do not reset level timing. No automatic /played requests or chat hooks are used.

The 750 ms tooltip delay, combat/cap behavior and existing session accounting remain intact. Expanded height grows by five UI units to keep source fills clear of text. Independent reviews and regression tests cover each feature, event ordering, layout bounds and temporary animation/timer cleanup. Native rendering and live event behavior still need in-game acceptance after reload.

## Earlier releases

See [release notes](https://github.com/elithrar/XPIsland/releases) for 0.4.3 and earlier.

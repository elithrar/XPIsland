# Resource audit

The 0.2 audit followed screenshot review, implementation and visual self-review. It covers Lua ownership and an offline stress run; it does not establish WoW native memory, GPU cost or taint safety.

## Findings and changes

An idle expanded panel redrew all 20 XP segments every second despite unchanged XP/color. In a 600-second simulation this caused 12,000 segment redraw calls. Cached progress and color now invalidate only on XP/color/layout changes: the same simulation produces zero idle redraws, followed by exactly 20 when XP changes. Time estimates continue updating through the existing shared ticker.

## Ownership review

- One event frame, 20 event registrations, no OnUpdate handlers. Initialization is guarded by the session owner.
- One shared one-second ticker owns clock accounting, queue expiry and visible rate/ETA refresh, including rate decay during idle. Display modes do not create tickers.
- One replaceable ten-second level-up timer. Manual toggles, profile application and dragging cancel it; repeated level-ups cancel and replace it.
- Zero-delay XP sampling is coalesced. Resize callbacks live only to the next timer dispatch. No recurring work is created by opening settings.
- Island geometry, eight cells, settings pages and ten reusable menu rows are created once. Profile switches change references and apply settings; they do not create new frames.
- Global logout/reload hooks are installed once per addon load. Optional stock-XP filtering restores only its owned method, or disables its token when another owner has wrapped it. It never unregisters another frame's events.
- Attribution awards/hints expire after two seconds; chat deduplication expires after three. These are time-window bounds, not an arbitrary maximum event count. Normal high-rate stream tests verify expiry and conservation.
- Profile and character tables grow only through explicit profile creation and use by distinct characters. Rate history has exactly 61 reusable minute slots at most, with total/kill counters per slot; it does not store individual events. There is no per-event session log or UI history. A fresh UI runtime is created after reload; session restoration validates saved data and the bounded rolling history, and excludes offline time.
- Short-lived formatting strings, value arrays and callbacks are garbage collected. The tests count retained resources separately from allocated bytes. An initial JIT-enabled probe showed trace-allocation noise between runs; the reproducible memory test disables the JIT compiler to isolate retained Lua data. The reported CPU time is therefore interpreter/mock time, not a gameplay benchmark.

## Reproducible checks

Run `luajit tests/stress_test.lua`. The test opens/closes settings and menus, switches two profiles, changes expansion, replaces/cancels level timers and sends repeated entering-world events for two 3,000-cycle windows after warmup. It asserts stable object/font/event counts, one live timer, unchanged profile/character cardinality, and bounded retained Lua growth in the second window.

`tests/rate_test.lua` additionally runs 10,000 online minutes and asserts the rate ring stays at 61 slots.

The stress test also sends 100,000 XP awards and source hints at 20 per simulated second. The observed maxima were 41 awards, zero unresolved hints and 61 deduplication IDs; all expired after advancing the clock. XP totals remained conserved. A machine-local result file is written to `dist/performance-results.txt` with object counts, post-GC memory deltas and CPU time.

The full game still needs a multi-hour soak covering quests, dungeon transitions, idle periods, combat, options, other addon skins, reload and reconnect. Test counts and LuaJIT timings are not estimates of WoW frame time or a claim that the addon is leak-free.

## Final local run

After the final design and rate changes: 216 UI objects stayed at 216, 47 registered font objects stayed at 47, 20 event registrations stayed at 20, and one ticker remained live. The two post-warmup 3,000-cycle windows retained 0.10 KiB and 0.00 KiB after garbage collection with JIT disabled. The complete mock stress run took approximately 1.54 seconds on the reviewing Mac. These measurements describe that run only.

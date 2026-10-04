# Resource audit

The 0.3 audit followed screenshot review, implementation and visual self-review. It covers Lua ownership and an offline stress run; it does not establish WoW native memory, GPU cost or taint safety.

## Findings and changes

An idle expanded panel redrew all 20 XP segments every second despite unchanged XP/color. In a 600-second simulation this caused 12,000 segment redraw calls. Cached progress and color now invalidate only on XP/color/layout changes: the same simulation produces zero idle redraws, followed by exactly 20 when XP changes. Time estimates continue updating through the existing shared ticker.

## Ownership review

- One event frame, 21 event registrations, no idle OnUpdate handlers; one temporary island OnUpdate during a transition. Initialization is guarded by the session owner.
- One shared one-second ticker owns clock accounting, queue expiry and visible rate/ETA refresh, including rate decay during idle. Display modes do not create tickers.
- One replaceable collapse timer: ten seconds for level-up, fifteen for manual opening when enabled. Hover/drag/settings suspend it; leaving restarts it. Profile changes reconcile the active policy. Combat and hiding cancel it. The existing clock reconciles pointer changes, with no added ticker.
- Zero-delay XP sampling is coalesced. Resize callbacks live only to the next timer dispatch. No recurring work is created by opening settings.
- Island geometry, the clipped detail container, eight cells and settings pages are created once. Native dropdown descriptions are regenerated as needed; Blizzard owns menu-row pooling. The mock checks XPIsland-owned objects, not that native pool. Profile switches change references and apply settings; they do not create new frames.
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

After the 0.3 design changes: 211 UI objects stayed at 211, 43 registered font objects stayed at 43, 21 event registrations stayed at 21, and one ticker remained live. The final post-warmup 3,000-cycle windows retained 0.30 KiB and 0.00 KiB after garbage collection with JIT disabled. The complete mock stress run took approximately 1.8 seconds on the reviewing Mac. A separate motion suite exercises 2,000 interrupted transitions with hover, profile changes and combat, asserting constant owned object counts and no idle animation script. These measurements describe those runs only.

## 0.4 animation work audit

The animation was already elapsed-time based and unthrottled. Its workload was the problem found in source: every frame repeated static radius/scale setup, cleared/rebuilt many anchors, reset identical colors and visibility flags, repainted invisible fills, and rendered the endpoint twice. It also scanned the rate model and refreshed fonts/text at completion.

Layout now owns fonts, font measurements, fixed anchors, scale and radius. Bar pieces cache color, visibility, shape and cap UV state separately; hidden fills do no native geometry work. Animated frames update changing dimensions, positions and coordinated opacity. The endpoint is rendered once, and the existing clock/event path owns model updates. Unchanged labels and stat values keep their measured text/font state at rest. There are no new recurring callbacks.

A before/after expansion at 10% XP, with identical instrumented mock APIs:

| Cadence | Delivered frames | 0.3 UI calls | 0.4 UI calls | Reduction |
| --- | ---: | ---: | ---: | ---: |
| 30 Hz | 7 | 3,533 | 736 | 79.2% |
| 60 Hz | 14 | 6,606 | 1,462 | 77.9% |
| 120 Hz | 27 | 12,313 | 2,810 | 77.2% |

`luajit tests/frame_work_test.lua` records current work counts for 0%, partial-cap, 10%, 47.5% and 100% XP to `dist/frame-work-results.txt`. Across those cases, averages are 100–143 counted API calls per delivered animation frame. No font/text/measurement/color/anchor-clear/texture-creation calls or rate-model scans occur inside Animate. Cadence-independent progress is compared at 100 ms. Jitter, long delays, interrupted reversal and a model change during motion are tested. A delayed frame advances to the current position; it cannot reconstruct frames the game did not render.

The baseline uses commit `8c612ad` UI code with the same instrumentation and initial 10%-XP state; its raw results remain in the local `dist/frame-work-before.txt`. These counters measure requested API operations, not native invalidation cost, render throughput or in-game FPS. The duration remains 220 ms. Native profiling is still needed if perceived lag persists.

With the corrected native-arrow mock and one new infinity texture, the stress run now retains 217 mock UI objects rather than 211; five of those six are mock representations of already-existing Blizzard arrows, not new addon objects. Counts remain constant across 6,000 cycles, 43 font registrations, 21 events and one clock. The second post-warmup memory window remained 0.00 KiB. Idle segments still produce zero redraws over 600 seconds.

## 0.4.1 loading ownership

Loading now keeps the existing session clock active. XP reads are gated independently, and the same ticker retries a settling XP/level sample only while one is pending. No recurring timer or UI object was added. Three event registrations cover loading start/end and player connection changes. The stress fixture drains the coalesced zero-delay entry read before counting quiescent timers. The final run retains 217 objects, 43 font registrations, 24 events and one clock across 6,000 cycles; its second memory window remains 0.00 KiB.

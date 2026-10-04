# 0.4.1 loading and estimate recovery

## Reproduced cause

Version 0.4.0 sampled unit values synchronously on PLAYER_LEAVING_WORLD and again while entering, without a loading-screen guard. Model.Sample marked any same-level XP decrease or unexpected level jump as `incomplete`, advanced its baseline anyway, and never cleared that flag. Estimate then returned no rate or ETA for the rest of that session, including reload restoration.

A deterministic reproduction using the released 0.4.0 model starts at level 10 with 100/1000 XP. A temporary 0/1000 read sets the flag while session earned XP is still zero. The next 100/1000 read incorrectly awards the same 100 XP again, while the flag continues disabling estimates. This demonstrates the bug; it does not establish the precise live event ordering in the user's session, which was not logged.

## Correct behavior

Loading, hearth travel, zoning and dungeon entry are online gameplay downtime. They advance session time and naturally lower the measured pace. The clock remains active across loading, including when no frame/ticker callback executes during a blocked loading screen; the next GetTime delta accounts for that duration. Unit reads are gated separately from the clock. Known connection state is retained while unit data is unavailable; explicit player UNIT_CONNECTION events and readable in-world connection state distinguish actual disconnects. Reload and disconnected wall time retain the existing resume policy.

Neither leaving-world nor loading-start performs a final XP read. Entry notifications are coalesced until both world entry and loading completion are observed, in either order. Unknown-location deltas count once as Other; subsequent dungeon gains use normal exclusive dungeon attribution. Pre-transition source hints cannot steal those gains.

The model retains its last valid baseline while an unexpected level/cap or backward value settles. The existing one-second ticker retries without allocating a new timer. A transient read that returns to the known baseline produces no new XP. Adjacent-level rollover uses the known old threshold after the new level/cap has settled; out-of-order level notifications receive a bounded retry. The effective cap still records the known final-level remainder once.

If a confirmed correction or multiple skipped thresholds truly prevents a complete calculation, recorded totals remain intact and no missing XP is invented. Only the rolling history restarts. Rate/ETA resumes after the normal minute of fresh history with XP. The ETA tooltip briefly says “Recalculating your leveling pace.” A source-total tooltip can say “Totals include recorded XP only.” The permanent “session contains a gap” warning is removed.

Saved 0.3/0.4 sessions with the old flag migrate once during ordinary addon restoration: counters remain, the old estimate veto clears, and rolling history restarts. No external edits of SavedVariables, user session reset, gameplay automation or forced reload are used.

## Verified contracts and tests

Matching Forever 1.60.1.70205 source documents [loading-screen events](https://github.com/Gethe/wow-ui-source/blob/e3ecc27b64d30fdc735a3f6579b866858f9f9df1/Interface/AddOns/Blizzard_APIDocumentationGenerated/LoadingScreenDocumentation.lua), [world-entry/exit flags](https://github.com/Gethe/wow-ui-source/blob/e3ecc27b64d30fdc735a3f6579b866858f9f9df1/Interface/AddOns/Blizzard_APIDocumentationGenerated/SystemDocumentation.lua) and [UNIT_CONNECTION / level / XP events](https://github.com/Gethe/wow-ui-source/blob/e3ecc27b64d30fdc735a3f6579b866858f9f9df1/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua).

`tests/recovery_test.lua` covers hearth, both entry/loading event orders, a frame-blocking load, elapsed-time rate/ETA changes, unavailable unit data, first-login loading, subsequent kills, dungeon and queued-event boundaries, temporary backward readings, explicit disconnection, both rollover orders, a delayed level notification with no follow-up XP event, unknown thresholds, stable corrections, the level cap, old-session migration and repeated travel with constant UI object ownership. These are mocked event-sequence regressions; native behavior still needs confirmation after the user loads the patch.

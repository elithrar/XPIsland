# 0.5.1 review

0.5.0 deliberately omitted automatic played requests because the inspected API had no documented silent argument. It used a local continuous observation counter, which unnecessarily lost level continuity on reload or disconnect. 0.5.1 removes that restriction using server-derived level-start anchors and a narrowly scoped Blizzard chat extension. It also corrects the presentation: the temporary duration belongs in the header pill, while the ETA stat remains live.

Two independent reviewers inspected timing and chat/UI behavior. Findings fixed before release:

- Accept a new level start equal to the previous snapshot's total played, while still requiring positive duration. Server counters have integer-second precision.
- Drain a manual request issued before XPIsland's own request; otherwise its delayed reply could be hidden.
- Separate anchor corroboration from quiet-response ownership. Normally drained manual requests no longer produce extra visible automatic lines. Timeout ambiguity still fails open.
- Clear the presentation eligibility window on root hide as well as explicit collapse.
- Prefer the native chat-window constant, and release ownership if RequestTimePlayed errors.
- A result received before a delayed level-up event remains available briefly for presentation. An early level-up event prevents requests against stale UnitLevel data.
- Duplicate connection notifications do not reset request budgets. Detected connection changes without an event still invalidate the request generation.

The final protocol persists only the current authoritative anchor, not a per-level elapsed estimate. Tests cover reload/login mid-level, reconnect/offline gaps, missing and duplicate responses, rollover races, old/invalid SavedVariables, independent session resets, bounded retries and chained chat handlers. Header tests cover the exact phrase, fitting fonts/scales/viewports, live ETA retention, full ten-second display, repeated levels, dismissal/combat/cap, restoration and stale callbacks.

Reviewers found no remaining concrete implementation blocker. The API has no response ID or level marker, so arbitrary concurrent/reordered replies cannot be perfectly attributed. Ambiguous data is omitted or corroborated; timeout ownership fails open. Native dispatch, actual server counters and chat-addon coexistence require in-game acceptance. Offline previews are mocked renderings, not game screenshots.

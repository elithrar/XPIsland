# XP, pet and Forever PvP progression contract

Implementation target: official Forever interface 16001. API source checked at
Blizzard UI snapshot `15666a6e67938a1ab5caf041406464251db111ca` (1.60.1.70245).
Rechecked against `9465cb273b5513495d8ecc12fbb19930dd6b8957` (1.60.1.70291):
the relevant pet/rank consumers and major-faction, currency, unit and chat API
definitions are unchanged.
This is source verification, not observed in-game behavior. Retail and Classic
remain unsupported.

## API and event ownership

- Core remains the sole player-XP sampler: `UnitXP`, `UnitXPMax`, `UnitLevel`,
  `GetXPExhaustion`, existing XP/quest/localized combat-XP notifications. XP deltas
  are authoritative; chat only classifies already observed XP.
- Progression reads `GetPetExperience()` and `UnitLevel("pet")`, guarded by
  `UnitExists("pet")` and pet GUID. Refresh on `UNIT_PET` for player,
  `UNIT_LEVEL` for pet, and world entry. Like Blizzard's pet XP bar, refresh on
  every `UNIT_PET_EXPERIENCE` regardless of payload, reading the current pet.
  The event is NOT PET_XP_UPDATE.
  Missing/non-leveling pets have no row; a valid zero numerator is real zero.
- Honor is currency, not a rank proxy. Read
  `C_CurrencyInfo.GetCurrencyInfo(Constants.CurrencyConsts.HONOR_CURRENCY_ID)`
  (1792 in the checked source); `quantity` means available balance, NOT earned
  this session. Refresh on `CURRENCY_DISPLAY_UPDATE` and world entry. No
  synthetic earnings, honor/hour, Retail honor levels, or spending-as-negative-XP.
- Forever PvP rank uses `C_MajorFactions.GetMajorFactionProgressionInfo(2800)`.
  `renownLevel` is rank; `renownReputationEarned / renownLevelThreshold` is current
  Rank Points / next-rank requirement. `maxLevel` is the seasonal maximum;
  `currentWeekProgressiveMaxLevel` is the current progressive ceiling, not honor
  or points earned this week. Use `GetTotalReputationForRenownLevel` to compute
  cumulative points and the available ceiling. Refresh on `UPDATE_FACTION`,
  `MAJOR_FACTION_RENOWN_LEVEL_CHANGED`, world entry, and season changes checked
  by the existing ticker. Missing/restricted/nonfinite values are unavailable.
- Runtime samples are not saved or mixed into XP totals. No new periodic timer,
  combat-log scan, protected action, or Blizzard honor-bar ownership is added.

Source: https://github.com/Gethe/wow-ui-source/tree/15666a6e67938a1ab5caf041406464251db111ca
See Camelot/PetExpBar.lua, Camelot/PVPRankFrame.lua, CurrencyInfoDocumentation.lua,
and Blizzard_PVPMatch/PVPMatchResults.lua. Honor vs Rank Points:
https://news.blizzard.com/en-us/article/24303316/how-pvp-progression-in-world-of-warcraft-forever-works

## Kill estimate and persistence

The existing all-source ETA formula is unchanged. Kills to level uses up to one
hour of confirmed kill XP AND kill counts, with the newest 20 minutes weighted
twice. It is ceil(remaining XP / weighted mean XP per kill), not a kill-rate ETA.
XP and count use identical minute-boundary prorating. At least five unweighted
window-equivalent kills are required. Empty/expired/small samples show a dash
with a reason, never infinity or a fabricated zero.

A separate version-1 `session.killHistory` stores at most 61 minute buckets, each
with its absolute session-minute index, XP and count. Old sessions begin empty;
invalid new history is discarded independently without losing valid XP totals.
Valid reload/reconnect restoration uses the existing online-session clock and
excludes offline time. Profiles do not own history. Explicit session reset/new
session clears history. Solo/group/dungeon changes, rested transitions and normal
level-ups preserve samples; corrections discard pending reconciliation, not
already confirmed samples. Actual rewarded XP includes bonuses. The estimate
assumes comparable future rewards; it does not forecast rested exhaustion.

Count one sample per uniquely identified, fully reconciled named kill hint,
including dungeon kills. One hint split across awards still adds ONE count;
several hints sharing a coalesced award each add one. Timestamp samples at original
hint observation. Unmatched, expired, missing-ID and unreadable hints do not
supply counts. Runtime line-ID deduplication lasts the full retained window and
is bounded to 8192 IDs; saturation stops accepting additional estimator samples
until space expires. IDs are not persisted because they belong to the current
client event stream. Restored aggregate buckets are independent of new IDs.

Settings remain schema 2 with additive validated fields: explicit mode (XP by
default), opt-in PvP-at-level-cap switch (false), pet/rank/kill inline visibility,
and independent PvP label choice. Existing format choices are preserved; the XP
label gains `N kills`, and the PvP label gains Rank Points to next. No existing
font/profile/played-time migration changes.

## Display and interaction

One expansion only. XP keeps its two four-cell rows and adds one centered compact
row of equal-size inline label/value pairs: Pet XP, PvP rank current/required,
and Kills to level. All inline text uses one size; pairs are centered as a group,
with absent/disabled items omitted. No second drawer, disclosure arrow, graph,
quests-in-log or party dashboard. Honor balance is explained in the PvP tooltip
and is a primary stat in Honor & PvP mode.

Honor & PvP mode shows the rank bar, clearly labeled as PvP progression, and a
compact summary of Honor available, PvP rank, Rank Points remaining and current
rank-cap progress. Irrelevant XP source/estimate rows are hidden. A leveling pet
may still appear. Explicit mode remains visible at player cap and during missing
PvP data; missing values use dashes, valid zero honor uses 0. A rank ceiling or
seasonal maximum stays visible with an explicit label, not an invented next rank.

XP retains its existing hide-at-cap/disabled behavior. The optional at-cap switch
checks actual effective player level, not merely disabled XP. Manual mode change
starts collapsed, cancels stale notices/tooltips/motion and does not reset XP.
No activity-driven auto-switching. Existing collapse/hover/combat rules remain.

## Required validation

Model: weighting XP/count equally, minute edges and expiry, low samples, solo and
dungeon retention, rollover/rested changes, reset/restore/invalid saved history,
split/coalesced reconciliation, late duplicate IDs and bounded saturation.
Runtime/UI: valid/absent/swapped pet, nil/secret APIs, spending honor, zero honor,
rank/weekly/season caps, actual cap vs XP disabled, mode changes and stale notices,
all fonts/scales/viewport directions, inline centering and shared sizing, no idle
OnUpdate or additional recurring timers. Run existing ETA, source accounting,
played-time, integration, motion, tooltip, performance and packaging suites.
Live Forever testing must verify currency identity/values, event ordering,
localized kill messages, real fonts and taint; offline mocks cannot establish it.


## Watched reputation contract (0.7.8)

Verified against the workflow pin `943764493e6b16d63ded3ab304150d1f05e58b57`
(Forever 1.60.1.70338). `C_Reputation.GetWatchedFactionData()` returns optional
`FactionData`; nil or faction ID 0 means no watched faction. The Camelot
`ReputationFrame.lua` checkbox calls `SetWatchedFactionByIndex` and its panel
refreshes on `UPDATE_FACTION`. XPIsland only reads the selection, refreshing on
world entry, `UPDATE_FACTION` and renown notifications through existing handlers.
It never sets the watched faction, expands the reputation list or hooks its UI.

`Progression:Reputation()` stores a runtime snapshot separate from XP accounting.
Ordinary progress subtracts `currentReactionThreshold` from `currentStanding`
and `nextReactionThreshold`; absolute negative standings are valid. Reaction 8
is the maximum ordinary standing. As in the pinned Shared/ReputationBar.lua,
paragon takes priority, then major factions, then friendship, then ordinary rep.
Paragon uses `GetFactionParagonInfo`, modulo its positive threshold and adding a
threshold for pending rewards. Major factions use `GetMajorFactionData`'s earned
reputation/threshold/renown level and `HasMaximumRenown`. Friendships use
`GetFriendshipReputation`'s standing/reaction/next thresholds; nil next threshold
means maximum. Full maximum bars never divide by zero or invent a next standing.
The friendship API is marked `MayReturnNothing`: an absent result falls through
to ordinary reputation, matching the native panel's type resolver. Restricted or
malformed friendship data remains unavailable rather than being treated as absent.
Unavailable or unreadable snapshots replace old data with dashes.

Schema 2 adds validated `mode="reputation"` and `reputationFormat` (percent,
fraction, left; percent default). The client owns the watched faction, so faction
IDs and reputation values are not profile data. Explicit reputation stays visible
at cap and takes precedence over `pvpAtCap`; manual mode choice disables that
policy. Existing XP and PvP formats remain independent. Native mode rows have
format submenus with the same profile/mode/per-opening callback guards.

`tests/reputation_test.lua` exercises the registered handlers and settings UI,
including threshold rollover, missing/restricted data, special reputations,
maximum states, visible tooltip refresh, long UTF-8 names, profile/reload
persistence, object reuse and one shared ticker. It also verifies generated API
contracts and the native watched-checkbox consumer when passed the pinned source.
Live event timing, submenu input/rendering and taint remain unobserved.

# Rested tooltip capacity

The user authorized shipping a practical approximation and tuning it later. The
line is now enabled. Its copy is `X.X% of max. rested XP` in the configured rested
bar color, or red `Max` at or above the modeled capacity. No qualifying text is
added to the tooltip. Existing explanations remain unchanged.

## Centralized assumption

`Model.restedCapacity` contains the tunable rule: **150% of the full current-level
XP requirement**, increased by **4% per committed Well Rested rank**, up to five
ranks. `RestedMaximum` evaluates `levelXP * 150 * (100 + 4 * rank) / 10000`, rounding
down to whole XP. The 150% base is a historical WoW convention and an accepted
approximation here; it has **not** been verified as Forever's server formula.
Neither character level cap nor XP remaining supplies this denominator.

The calculation uses integer-first arithmetic: naive `1000 * 1.5 * 1.12` is
slightly greater than 1680 in double precision and would miss an exact modeled
cap. Below-cap display is limited to 99.9% until the actual modeled threshold is
reached; no broad tolerance promotes a nearly full pool to `Max`.

## Current source and data

Only Forever interface 16001 ships. CI pins
[`943764493e6b16d63ded3ab304150d1f05e58b57`](https://github.com/Gethe/wow-ui-source/tree/943764493e6b16d63ded3ab304150d1f05e58b57)
(1.60.1.70338). Runtime evidence is from 70425, whose matching source is
[`b401e0332adfbf0460d319b06d8ea29279a941f1`](https://github.com/Gethe/wow-ui-source/tree/b401e0332adfbf0460d319b06d8ea29279a941f1).
The rested/trait APIs used here have the same relevant contracts in both builds.

- `GetXPExhaustion()` supplies the current pool. Nil means no bonus; unreadable,
  negative or non-finite data does not produce a percentage or `Max`.
- `GetRestState()` supplies state/name/XP award factor, not capacity.
- No effective-cap accessor was found in the generated APIs. The implementation
  does not claim an undocumented accessor is impossible.
- [Blizzard's Legacy overview](https://news.blizzard.com/en-us/article/24307383/get-to-know-the-world-of-warcraft-forever-legacy-system)
  explicitly distinguishes increased capacity and faster accumulation.

Matching DB2 exports for 70338, 70374 and 70425 give these records:

| Record | Value |
| --- | --- |
| Adventure tree / node / entry / definition | 1188 / 110301 / 136855 / 141618 |
| Well Rested spell / maximum ranks | 1225478 / 5 |
| Capacity description (`$s2`) curve | 99769 |
| Rank 1 / 2 / 3 / 4 / 5 increase | 4% / 8% / 12% / 16% / 20% |
| Additional matching effect | index 2, numeric aura 656, curve 121614 |

Sources: [70425 trait effects](https://wago.tools/db2/TraitDefinitionEffectPoints/csv?build=1.60.1.70425),
[70425 curve points](https://wago.tools/db2/CurvePoint/csv?build=1.60.1.70425).
Aura 656's capacity role is inferred from the description/matching curves, rather
than a named generated aura enum. Its curve agrees with the description curve.
The inspected complete spell data found no other capacity modifier. Camp Tent
(spell 1307230) fills the pool to 5% of a level and has no effect above that value;
this is a pool grant, not an increase to maximum capacity. Future modifiers may
require updating the central rule.

An installed 70374 `gametables/xp.txt` extraction (file ID 1391661, content key
`f19db4c245ead0a3926803c85134e6b1`, SHA-256
`935253a23756f0ab7a760e8e4ab22184e1aca49285944ea68efc0a8820e459e6`)
had level 1-59 requirements divisible by 100. All 354 level/rank combinations
therefore yield integral candidate capacities. This checks arithmetic; it does
not establish the assumed server base or exclude server overrides.

## Perk sampling and transitions

`C_Traits.GetConfigIDByTreeID(1188)` resolves the configuration. Validated
`GetNodeInfo(configID, 110301).activeRank` is sampled only when
`ConfigHasStagedChanges(configID)` is false. While editing, the same configuration
may retain its last confirmed rank; a different or initially staged configuration
cannot borrow that rank. Commits, configuration changes, and relevant node changes
coalesce sampling to the next frame.

A nil configuration alone is unavailable. A zero bonus is accepted for locked
Legacy only when readable faction 2802 data consistently gives `isUnlocked=false`,
`renownLevel=0`, and `GetCurrentRenownLevel(2802)=0`. The native Legacy bootstrap
uses this faction's renown to gate access. Unknown/conflicting data stays unknown;
zero unspent currency does not prove zero ranks. Faction unlock/renown events and
the existing shared ticker recover late data. No recurring timer is added.

Pending level transitions temporarily omit the line, preventing a new pool from
being compared with the old level requirement. The visible owned tooltip refreshes
with pool, perk, and appearance changes. Character level cap and disabled XP do not
supply a rested `Max` label.

## User observation and limitation

Matt reported a fully rested level 19 Warrior and supplied
`70425 21300 false 5 8896`: build, full level XP requirement, staged flag, Well
Rested rank, current pool. The accompanying screenshot shows `19,752 / 21,300
(92.7%)` and an infinity indicator with `No XP earned this session.` The infinity
is the empty-session ETA state; the bar preview clips rested XP at the current
level's end. Neither is a capacity indicator.

The reported full state and 8,896 XP pool do **not** agree with the adopted
approximation, which gives capacity 38,340 and displays **23.2%** for that pool.
The observation is retained as a regression and an unresolved difference. It is
not used to infer a universal 8,896/21,300 ratio. The user explicitly accepted
shipping an approximation without further validation gates or tooltip caveats.

Tests cover all ranks, exact/near boundaries, the observed snapshot, infinity/ETA
independence, committed-versus-staged changes, locked/unknown Legacy, restricted
values, late recovery, colors, ownership and rollover. Offline tests and source
inspection do not establish the actual Forever cap, native rendering, or taint
behavior. Installation does not reload the client; loaded code changes on reload.

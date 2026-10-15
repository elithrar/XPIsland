# Rested capacity investigation

The proposed secondary tooltip line requires a verified **effective** capacity.
The current draft deliberately has no runtime `restedMaximum` producer. Its
formatter and renderer are prepared and tested with explicit fixture capacities;
this is not an enabled feature or in-game acceptance.

## Verified client data

Only Forever interface 16001 is shipped. The repository pins
[`943764493e6b16d63ded3ab304150d1f05e58b57`](https://github.com/Gethe/wow-ui-source/tree/943764493e6b16d63ded3ab304150d1f05e58b57)
(1.60.1.70338). The installed MONOLITH beta is 1.60.1.70374, matching
[`735496de78ebd30ce816a0637982c556987f258c`](https://github.com/Gethe/wow-ui-source/tree/735496de78ebd30ce816a0637982c556987f258c).

- [`GetXPExhaustion`](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerScriptDocumentation.lua)
  returns the current pool (a nilable number). The native
  [XP bar](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_StatusTrackingBar/Shared/ExpBar.lua)
  consumes it as XP, not a capacity or percentage. Nil means no rested bonus.
- `UnitXPMax("player")` is the full current-level requirement, not XP remaining.
  Neither character level cap nor XP-disabled state establishes rested capacity.
- `GetRestState()` supplies state, name and an XP award factor; native tooltip
  code uses the factor as the earned-XP multiplier. It is not a capacity modifier.
- No effective-cap or fully-rested accessor was found in either build's generated
  API contracts. A read-only API-name scan of the installed `WowB.exe` found
  `GetXPExhaustion` and `GetBillingTimeRested`, but no cap/fully-rested accessor.
  This does not establish that an undocumented accessor cannot exist.

[Blizzard's Legacy overview](https://news.blizzard.com/en-us/article/24307383/get-to-know-the-world-of-warcraft-forever-legacy-system)
confirms that Well Rested changes accumulation **and capacity**. Matching client
DB2 exports establish the following records in **both** 70338 and 70374:

| Record | Value |
| --- | --- |
| Adventure trait tree | 1188 |
| Well Rested node / entry / definition | 110301 / 136855 / 141618 |
| Spell | 1225478 |
| Maximum ranks | 5 |
| Capacity description (`$s2`) | spell effect index 1, curve 99769 |
| Additional matching spell effect | index 2, aura 656, curve 121614 |
| Rank 1 / 2 / 3 / 4 / 5 capacity increase | 4% / 8% / 12% / 16% / 20% |

Reproduce with Wago's public client-data exports, replacing the table name with
`TraitNode`, `TraitNodeXTraitNodeEntry`, `TraitNodeEntry`, `TraitDefinition`,
`TraitDefinitionEffectPoints`, `CurvePoint`, `Spell`, or `SpellEffect`:
[70374 trait effect records](https://wago.tools/db2/TraitDefinitionEffectPoints/csv?build=1.60.1.70374),
[70338 trait effect records](https://wago.tools/db2/TraitDefinitionEffectPoints/csv?build=1.60.1.70338),
[70374 curve points](https://wago.tools/db2/CurvePoint/csv?build=1.60.1.70374).
The complete effect-points and curve-point exports were byte-identical between
these two builds. Their SHA-256 hashes were respectively
`8cd2e0422a2ddba275b950e9b8de11d5032a38c35d5edcba33f94102de901d2d` and
`b32aedd7442bc7e3499c6b122773837336345127abacc6095365ac30f7809324`.

All three Well Rested effect curves have the same rank values. Aura 656 is not
named by the inspected generated API, so its capacity role is an inference from
the spell description and matching effect, rather than a documented aura enum.
The complete 70374 spell-effect export contained no other aura-656 effect. The
spell-description scan found no other rested-capacity modifier. This bounds the
current data investigation; it does not guarantee future builds add no modifiers.

## Rank and refresh contract

The native [Legacy tree](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_LegacySystem/Blizzard_LegacyTree.lua)
uses `C_Traits.GetConfigIDByTreeID(1188)` and
`C_Traits.ConfigHasStagedChanges(configID)`. The
[generated trait API](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua)
exposes `GetNodeInfo(configID, 110301)`, but does not promise that its ranks exclude
staged edits. `entryIDsWithCommittedRanks` identifies entries, not rank counts.
Do not interpret a missing config as a zero-rank perk: the inspected source does
not establish that equivalence.

An adapter can retain a confirmed **unstaged** rank for the same configuration
while changes are staged. An unknown/staged configuration must stay unavailable.
The native [shared talent frame](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_SharedTalentUI/Blizzard_SharedTalentFrame.lua)
uses `TRAIT_CONFIG_UPDATED` to recognize commit success. Config creation/list
updates, world entry and level changes also need resampling. Node-change events
alone can describe a preview. The
[curve API](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/CurveUtilDocumentation.lua)
can evaluate game curve 121614 at the validated rank.

## Remaining blocking evidence

The inspected current sources and data do **not** establish Forever's base-cap
equation or the server/API rounding of a fractional effective capacity. A fixed
`1.5 * UnitXPMax` is therefore not enabled as a fallback. The current
[DataStore implementation](https://github.com/Thaoky/DataStore_Characters/blob/9585575ecc1b43b1d8d68650b0cd5d2f0512c081/DataStore_Characters/DataStore_Characters.lua)
uses that historical base, but its explicit Forever branch changes event wiring;
the rested calculation remains generic and documents older reporting anomalies.
It cannot establish a current Forever server contract. `Exhaustion.db2` also does
not supply a documented equation establishing the base.

Even if 150% is verified, naive `1000 * 1.5 * 1.12` evaluates slightly above 1680
in double precision and can incorrectly withhold `Max`. For an integer percentage
bonus, `levelXP * 3 * (100 + bonusPercent) / 200` avoids that particular error.
Server rounding at non-integral boundaries still needs independent confirmation;
a broad one-XP tolerance could falsely mark a genuinely incomplete pool as full.

No game process or Forever game-state query bridge was running during inspection.
No addon was installed or game files changed. To close the gap, collect the
following read-only values on a **known fully rested** leveling character, with
no staged Legacy edits, including zero and nonzero Well Rested ranks and a level
whose proposed effective capacity is fractional:

```lua
/run print("build",select(2,GetBuildInfo()),"level",UnitLevel("player"),"levelXP",UnitXPMax("player"),"restedXP",GetXPExhaustion())
/run local c=C_Traits.GetConfigIDByTreeID(1188); print("config",c); if c then print("staged",C_Traits.ConfigHasStagedChanges(c)); DevTools_Dump(C_Traits.GetNodeInfo(c,110301)) end
```

These values are an evidence request, not an assertion that the proposed formula
or rank semantics have already been observed in game. The independent review
confirmed the same unresolved base and rounding gaps.

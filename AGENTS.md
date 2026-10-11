# Repository instructions

## Code and contracts

- XPIsland targets WoW Forever. Read the current interface in `XPIsland/XPIsland.toc`; verify API changes against the Blizzard source revision pinned in `.github/workflows/check.yml`, not Retail or Classic assumptions.
- `XPIsland/` is the shipped addon. `Model.lua` owns XP accounting and saved-data validation; `Core.lua` owns events and the shared ticker; `Progression.lua` samples pet/PvP state; `Played.lua` handles authoritative played time; `UI.lua` and `Options.lua` own presentation. Preserve the TOC load order and shared `ns` namespace.
- Keep XP deltas authoritative, progression snapshots separate from XP totals, and saved-data migrations compatible. Consult `docs/BEHAVIOR.md` and `docs/PROGRESSION-CONTRACT.md` when changing these contracts.
- Guard secret/restricted API values before consuming them; use `ns.Model.Number` (aliased as `M.Number` in modules) for finite, readable numbers. Preserve Blizzard/other-addon callback and event ownership, and defer protected frame visibility changes during combat.
- Reuse the shared ticker for recurring work and cache UI objects. Keep font selection, text measurement and object creation out of animation callbacks; use `docs/PERFORMANCE.md` and the frame-work/stress tests for performance changes.

## Development and validation

Use LuaJIT, Python 3 and Git from the repository root. Create `dist/` before Lua tests that write fixtures. For a focused runtime check:

```sh
mkdir -p dist
luajit tests/runtime_test.lua
```

- Run the full **Test model and runtime** command list in `.github/workflows/check.yml` for addon behavior changes, including `luajit tests/font_startup_test.lua --fail-paths`. Add focused regression coverage in the relevant `tests/*_test.lua`; `tests/wow_mock.lua` supplies the deterministic runtime.
- For the CI-equivalent API checks, use the workflow's pinned `Gethe/wow-ui-source` revision and sparse paths under `.blizzard-api/`. Pass `.blizzard-api/Interface/AddOns` to `tests/played_test.lua` and `tests/stock_tracking_test.lua`; omitting it runs only their mock checks.
- Run `python3 tests/release_test.py` for offline release guards and `python3 tests/package.py` for manifest, Lua syntax, bindings, assets and ZIP validation. Packaging also requires `luajit` on `PATH`; it writes `dist/XPIsland-<version>.zip` and `dist/SHA256SUMS` without publishing.
- Keep test output and release archives in ignored `dist/`. If shipped files change, update the TOC and `tests/package.py` manifest expectations as applicable; the ZIP must contain only the addon under `XPIsland/`.
- Report checks run and remaining live checks in the PR. Mocks and offline previews do not establish native rendering, taint safety or in-game performance; follow `docs/VALIDATION.md` and, for progression changes, `docs/PROGRESSION-LIVE-CHECKLIST.md`.

## Releases

- Merging to `main` runs **Check addon**; it does not publish. `.github/workflows/release.yml` publishes on a `v*` tag push or manual dispatch with an existing tag. Pushing release tags, dispatching this workflow or running publish scripts requires an explicit release request; a merge request alone does not authorize publication.
- For an authorized release, follow `docs/RELEASING.md`: align the version in `XPIsland/XPIsland.toc` and `XPIsland/Core.lua`, add `docs/releases/<version>.md`, and pass checks before pushing a matching annotated `v<version>` tag whose commit is reachable from `origin/main`. Never move a published tag.
- The workflow publishes the validated ZIP to GitHub and, when configured, CurseForge. Preserve the existing checksum/receipt guards; reconcile an uncertain CurseForge upload before retrying. Report upload acceptance separately from moderation/public visibility.

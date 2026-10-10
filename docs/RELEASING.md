# Releases

Push an annotated `v*` tag whose commit is already reachable from `origin/main`. The tag version must exactly match both `XPIsland.toc` and `Core.lua`; add `docs/releases/<version>.md` before tagging. Lightweight tags, off-main commits, mismatched versions and extra game flavors fail before publication.

```sh
git switch main
git pull --ff-only
# Commit the version bump, release notes and reviewed changes; wait for Check addon.
git push origin main
git tag -a v0.4.0 -m 'XPIsland 0.4.0'
git push origin v0.4.0
```

Tags themselves do not belong to branches. The workflow fetches `origin/main` and checks ancestry rather than assuming a tag-push branch filter enforces main. Do not move a published tag; use a new version for corrections. A manual run of Release addon with the existing tag resumes publication without moving it.

| Tag | GitHub | CurseForge |
| --- | --- | --- |
| `v0.4.0` | Normal release | Release |
| `v0.5.0-alpha.1` | Prerelease | Alpha |
| `v0.5.0-beta.1` or `v0.5.0-rc.1` | Prerelease | Beta |

The read-only validation job runs all addon and release tests, verifies Forever 1.60.1/interface 16001, then creates a reproducible ZIP containing exactly the thirteen addon files under `XPIsland/`. It publishes a build artifact. A separate job uses the standard job-scoped `GITHUB_TOKEN` with `contents: write` to attach that ZIP, SHA256SUMS and release metadata to GitHub. No new PAT is needed. Checkout/artifact actions are pinned to full commit IDs; checkout does not persist credentials. Concurrent releases of the same tag are serialized. Reruns verify an existing ZIP instead of replacing different bytes.

## CurseForge setup

Project ID 1727059 is recorded in the TOC. Generate an upload token in [CurseForge API Tokens](https://authors.curseforge.com/#/api-tokens), then add it securely as `CF_API_TOKEN` in [repository Actions secrets](https://github.com/elithrar/XPIsland/settings/secrets/actions). The already-configured `CF_API_KEY` name is also accepted and mapped to the uploader’s `CF_API_TOKEN` environment variable. If both exist, `CF_API_TOKEN` takes precedence. Never put it in chat, source, a command argument or release notes. The token is exposed only to the optional publish steps; validation has no upload credentials.

If the secret is absent, GitHub publication continues and the workflow emits an explicit warning and summary that CurseForge was not attempted. Add the secret and manually rerun Release addon for the same tag. An invalid token, ambiguous upload, missing exact game version or rejected upload fails the upload step; it is not silently reported as success.

The uploader resolves only the Forever type 88568 and version 1.60.1, refusing fallback to another patch or flavor. It sends the same validated ZIP bytes and selects `release`, `alpha` or `beta` from the tag. BigWigs packager 2.6.0 introduced Forever support, confirmed in reviewed 2.6.1 source; this repository retains its existing ZIP builder and uses the documented CurseForge upload API directly to avoid repackaging or automatic version fallback.

Before an upload POST, a `curseforge-upload-pending.json` asset records intent. Success adds `curseforge-receipt.json` with the returned file ID, hash, version and classification. Reruns with a receipt do not upload again. An unresolved pending marker blocks retries: inspect [project files](https://authors.curseforge.com/#/projects/1727059/files) first. If the file exists, reconcile its ID/receipt; remove a pending marker only after confirming no file was created. POSTs are never automatically retried after timeouts.

A successful API response confirms acceptance of an upload, not moderation approval or public visibility. A stable tag requests the Release file classification with automatic release after approval. Changing an existing uploaded file from Alpha/Beta to Release is a separate file update; this workflow publishes the new version and does not relabel older files. Check the author dashboard for pending approval, required project metadata, or rejected files.

## Sources

- [GitHub tag-push events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#push)
- [CurseForge Upload API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-upload-api)
- [BigWigs packager 2.6.0 Forever support](https://github.com/BigWigsMods/packager/releases/tag/v2.6.0)
- [Reviewed 2.6.1 flavor mapping and upload behavior](https://github.com/BigWigsMods/packager/blob/e50a250f8705041e40f2fa1ddcb280a686d65aa0/release.sh)

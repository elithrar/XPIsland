"""Publish the exact validated ZIP with GitHub's job-scoped token."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def gh(*args, **kwargs):
    return subprocess.check_output(['gh', *args], text=True, **kwargs).strip()


def main():
    data = json.loads((ROOT / 'dist/release.json').read_text())
    tag, archive = data['tag'], ROOT / 'dist' / data['archive']
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    expected = (ROOT / 'dist/SHA256SUMS').read_text().split()[0]
    if digest != expected:
        raise ValueError('Release artifact hash does not match validation output')
    # A read/list failure aborts; it is never interpreted as "no release".
    releases = json.loads(gh('api', '--paginate', '--slurp', 'repos/{owner}/{repo}/releases'))
    existing = next((r for page in releases for r in page if r['tag_name'] == tag), None)
    if existing:
        # Reruns may finish a draft but cannot overwrite an existing ZIP.
        names = {a['name'] for a in existing['assets']}
        if data['archive'] in names:
            with tempfile.TemporaryDirectory() as directory:
                gh('release', 'download', tag, '--pattern', data['archive'], '--dir', directory)
                if hashlib.sha256((Path(directory) / data['archive']).read_bytes()).hexdigest() != digest:
                    raise ValueError('Existing release has different ZIP bytes; publish a new version')
        else:
            gh('release', 'upload', tag, str(archive))
        for name in ('SHA256SUMS', 'release.json'):
            if name not in names:
                gh('release', 'upload', tag, str(ROOT / 'dist' / name))
    else:
        args = ['release', 'create', tag, str(archive), str(ROOT / 'dist/SHA256SUMS'),
                str(ROOT / 'dist/release.json'), '--verify-tag', '--draft', '--title', f'XPIsland {tag}',
                '--notes-file', str(ROOT / 'docs/releases' / (data['version'] + '.md'))]
        if data['prerelease']:
            args.append('--prerelease')
        gh(*args)
    gh('release', 'edit', tag, '--draft=false', '--prerelease=' + str(data['prerelease']).lower())
    print(gh('release', 'view', tag, '--json', 'url', '--jq', '.url'))


if __name__ == '__main__':
    main()

"""Release metadata and Git safety checks. No credentials or network writes."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

VERSION = r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-(alpha|beta|rc)\.([1-9][0-9]*))?'
ROOT = Path(__file__).resolve().parents[1]


def metadata(tag, toc):
    match = re.fullmatch('v' + VERSION, tag)
    if not match:
        raise ValueError('Use vX.Y.Z, vX.Y.Z-alpha.N, vX.Y.Z-beta.N or vX.Y.Z-rc.N')
    version = re.search(r'^## Version: (.+)$', toc, re.M)
    if not version or version[1] != tag[1:]:
        raise ValueError('Tag must exactly match the TOC version')
    if re.findall(r'^## Interface[^:]*: (.+)$', toc, re.M) != ['16001']:
        raise ValueError('This release supports only Forever 1.60.1 (16001)')
    project = re.search(r'^## X-Curse-Project-ID: (.+)$', toc, re.M)
    if not project or project[1] != '1727059':
        raise ValueError('Unexpected CurseForge project')
    kind = 'alpha' if match[4] == 'alpha' else 'beta' if match[4] else 'release'
    return dict(tag=tag, version=tag[1:], release_type=kind,
                prerelease=kind != 'release', archive=f'XPIsland-{tag[1:]}.zip',
                project_id=1727059, game_version='1.60.1', game_version_type=88568)


def git(*args, cwd=ROOT):
    return subprocess.check_output(['git', *args], cwd=cwd, text=True).strip()


def check_tag(tag, cwd=ROOT):
    ref = f'refs/tags/{tag}'
    if git('cat-file', '-t', ref, cwd=cwd) != 'tag':
        raise ValueError('Release tags must be annotated: git tag -a ...')
    commit = git('rev-parse', f'{ref}^{{commit}}', cwd=cwd)
    if git('rev-parse', 'HEAD', cwd=cwd) != commit:
        raise ValueError('Checkout must be the tagged commit')
    if subprocess.run(['git', 'merge-base', '--is-ancestor', commit, 'origin/main'], cwd=cwd).returncode:
        raise ValueError('Tagged commit is not reachable from origin/main')
    return commit


def main():
    tag = os.environ.get('RELEASE_TAG') or sys.argv[1]
    data = metadata(tag, (ROOT / 'XPIsland/XPIsland.toc').read_text())
    data['commit'] = check_tag(tag)
    notes = ROOT / 'docs/releases' / (data['version'] + '.md')
    if not notes.is_file():
        raise ValueError('Add version-specific release notes before tagging')
    (ROOT / 'dist').mkdir(exist_ok=True)
    (ROOT / 'dist/release.json').write_text(json.dumps(data, indent=2) + '\n')
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            for key in ('tag', 'version', 'archive', 'release_type', 'commit'):
                output.write(f'{key}={data[key]}\n')
    print(f"Validated {tag}: {data['release_type']}, Forever 1.60.1, commit {data['commit']}")


if __name__ == '__main__':
    main()

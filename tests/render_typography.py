"""Optional offline font proof: pip install fonttools; requires local Chrome.

Pass one or more --font paths. Fonts stay local and are embedded only in dist/
proofs; neither font files nor user screenshots are committed or packaged.
This exercises layout with hmtx advances and renders actual outlines in Chrome,
not WoW's rasterizer, shaping engine, native controls or live frame hierarchy.
"""
import argparse
import base64
import html
import json
import re
import time
from pathlib import Path
import subprocess
import tempfile
from fontTools.ttLib import TTFont

parser = argparse.ArgumentParser()
parser.add_argument('--font', action='append', required=True, type=Path)
parser.add_argument('--screenshot-cases', action='store_true', help='Bottom drawer, rank 0 / 750, and 85/90/95/100 percent scales from the supplied old-client images')
parser.add_argument('--chrome', default='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
out = root / ('dist/typography-screenshots' if args.screenshot_cases else 'dist/typography')
out.mkdir(parents=True, exist_ok=True)
cards = []
coverage = []
for index, path in enumerate(args.font):
    font = TTFont(path)
    cmap = font.getBestCmap()
    units = font['head'].unitsPerEm
    chars = [chr(n) for n in range(32, 127)] + ['—', '∞', '·']
    metrics = {ch: font['hmtx'].metrics[cmap[ord(ch)]][0] / units for ch in chars if ord(ch) in cmap}
    metrics_path = out / f'font-{index}.lua'
    metrics_path.write_text('return {' + ','.join(f'[{json.dumps(ch, ensure_ascii=False)}]={width}' for ch, width in metrics.items()) + '}\n')
    coverage.append({'font': path.name, 'infinity_glyph': 0x221E in cmap, 'em_dash_glyph': 0x2014 in cmap})
    encoded = base64.b64encode(path.read_bytes()).decode('ascii')
    for scale in ((.85, .9, .95, 1) if args.screenshot_cases else (.5, .85, 1, 1.5)):
        for mode in (('percent', 'eta') if args.screenshot_cases else ('percent', 'eta', 'pvp', 'pvp-wide')):
            target = out / f'{index}-{scale}-{mode}.svg'
            subprocess.run(['luajit', 'tests/typography_preview.lua', str(metrics_path), str(scale), mode, str(target), 'screenshots' if args.screenshot_cases else 'general'], cwd=root, check=True)
            svg = target.read_text().replace('font-family="Georgia"', f'font-family="Proof{index}"')
            # Inline SVG IDs are document-global. Namespace clip paths so one
            # 50% card cannot accidentally clip every following 85/100% card.
            prefix=f'proof{index}_{scale}_{mode}_'
            for ident in re.findall(r'id="([^"]+)"', svg):
                svg=svg.replace(f'id="{ident}"', f'id="{prefix}{ident}"').replace(f'url(#{ident})',f'url(#{prefix}{ident})')
            style = f'<style>@font-face{{font-family:Proof{index};src:url(data:font/ttf;base64,{encoded})}}</style>'
            svg = svg.replace('><rect', '>' + style + '<rect', 1)
            target.write_text(svg)
            placement = 'bottom · rank 0 / 750' if args.screenshot_cases else 'top'
            cards.append(f'<section><h2>{html.escape(path.name)} · {scale:.0%} · {mode} · {placement}</h2>{svg}</section>')
    font.close()
proof = out / 'proof.html'
proof.write_text('<!doctype html><meta charset="utf-8"><style>body{background:#101218;color:#ddd;font:16px sans-serif;margin:20px}main{display:grid;grid-template-columns:900px 900px;gap:12px}section{background:#242831}h2{font-size:16px;margin:12px}svg{display:block}</style><h1>Offline typography proof</h1><p>Actual local font outlines and advances; mocked WoW layout. Not in-game screenshots.</p><main>' + ''.join(cards) + '</main>')
(out / 'font-coverage.json').write_text(json.dumps(coverage, indent=2) + '\n')
with tempfile.TemporaryDirectory(prefix='xpisland-type-chrome-') as profile:
    image=out/'proof.png'
    image.unlink(missing_ok=True)
    height=150+280*((len(cards)+1)//2)
    process=subprocess.Popen([args.chrome, '--headless', '--disable-gpu', '--no-first-run', '--disable-background-networking', '--disable-component-update', '--hide-scrollbars', '--run-all-compositor-stages-before-draw', '--virtual-time-budget=3000', '--force-device-scale-factor=1', f'--user-data-dir={profile}', f'--screenshot={image}', f'--window-size=1870,{height}', proof.as_uri()], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        deadline=time.monotonic()+35
        while not image.exists() and time.monotonic()<deadline:
            time.sleep(.2)
        assert image.exists(), 'Chrome did not render the font proof'
    finally:
        process.terminate()
        try: process.wait(timeout=3)
        except subprocess.TimeoutExpired: process.kill();process.wait()
print(out / 'proof.png')
print(json.dumps(coverage))

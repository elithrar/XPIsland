"""Render the Lua mock's SVG fixtures. These are not in-game screenshots."""
from pathlib import Path
import concurrent.futures
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[1]
chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

def render(name):
    output = root / "dist" / f"preview-{name}.png"
    output.unlink(missing_ok=True)
    with tempfile.TemporaryDirectory(prefix="xpisland-preview-") as profile:
        args = [chrome, "--headless", "--disable-gpu", "--disable-background-networking",
                "--disable-component-update", "--no-first-run", f"--user-data-dir={profile}",
                f"--screenshot={output}", "--window-size=1728,1080",
                (root / "dist" / f"preview-{name}.svg").as_uri()]
        process = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            deadline = time.monotonic() + 25
            while not output.exists() and time.monotonic() < deadline:
                time.sleep(0.2)
            assert output.exists(), f"Failed to render {name}"
        finally:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
    print(f"Rendered offline {name} fixture")

with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    list(pool.map(render, ["collapsed", "expanded", "options", "profiles", "bottom", "readable", "transition", "centered", "settings-03", "profiles-03", "padding-04", "infinity-04", "settings-04", "profiles-04", "rested-05", "sources-05", "level-05", "highlight-05", "level-wrap-05", "durations-052", "durations-disabled-052", "progression-xp", "progression-pvp", "progression-settings"]))

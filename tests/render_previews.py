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
    list(pool.map(render, ["collapsed", "expanded", "options", "profiles"]))

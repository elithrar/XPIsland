"""Validate manifest/assets and produce the standalone local addon ZIP."""
from pathlib import Path
import hashlib
import os
import struct
import subprocess
import zipfile
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
addon = root / "XPIsland"
toc = (addon / "XPIsland.toc").read_text()
assert "## Interface: 16001" in toc
assert "## SavedVariables: XPIslandDB" in toc
assert "## SavedVariablesPerCharacter: XPIslandSession" in toc
files = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith("#")]
assert files == ["Model.lua", "UI.lua", "Options.lua", "Core.lua"]
for name in files:
    path = addon / name
    assert path.is_file()
    subprocess.run(["luajit", "-b", str(path), os.devnull], check=True)
bindings = ET.parse(addon / "Bindings.xml").getroot()
assert bindings.find("Binding").attrib["name"] == "XPISLAND_TOGGLE"
data = (addon / "media" / "rounded.tga").read_bytes()
assert len(data) == 18 + 64 * 64 * 4
assert struct.unpack_from("<HH", data, 12) == (64, 64)
assert data[16] == 32
out = root / "dist" / "XPIsland-0.1.0.zip"
out.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for path in sorted(addon.rglob("*")):
        if path.is_file() and not path.name.startswith("."):
            z.write(path, path.relative_to(root))
with zipfile.ZipFile(out) as z:
    assert z.testzip() is None
    assert all(name.startswith("XPIsland/") for name in z.namelist())
    assert "XPIsland/XPIsland.toc" in z.namelist()
digest = hashlib.sha256(out.read_bytes()).hexdigest()
(root / "dist" / "SHA256SUMS").write_text(f"{digest}  {out.name}\n")
print(f"PASS: manifest, Lua syntax, bindings XML, TGA and ZIP integrity; {out.name} ({out.stat().st_size} bytes)")

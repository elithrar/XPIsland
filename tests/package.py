"""Validate manifest/assets and produce the standalone local addon ZIP."""
from pathlib import Path
import hashlib
import os
import re
import struct
import subprocess
import zipfile
import xml.etree.ElementTree as ET
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from release import VERSION

root = Path(__file__).resolve().parents[1]
addon = root / "XPIsland"
toc = (addon / "XPIsland.toc").read_text()
assert "## Interface: 16001" in toc
assert "## X-Curse-Project-ID: 1727059" in toc
assert "## SavedVariables: XPIslandDB" in toc
assert "## SavedVariablesPerCharacter: XPIslandSession, XPIslandPlayed" in toc
files = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith("#")]
assert files == ["Model.lua", "Played.lua", "UI.lua", "Options.lua", "Core.lua"]
for name in files:
    path = addon / name
    assert path.is_file()
    subprocess.run(["luajit", "-b", str(path), os.devnull], check=True)
bindings = ET.parse(addon / "Bindings.xml").getroot()
assert bindings.find("Binding").attrib["name"] == "XPISLAND_TOGGLE"
for asset in ["rounded.tga", "cap.tga", "infinity.tga"]:
    data = (addon / "media" / asset).read_bytes()
    assert len(data) == 18 + 64 * 64 * 4
    assert struct.unpack_from("<HH", data, 12) == (64, 64)
    assert data[16] == 32
version = re.search(r"^## Version: (" + VERSION + r")$", toc, re.M).group(1)
assert f'version="{version}"' in (addon / "Core.lua").read_text()
out = root / "dist" / f"XPIsland-{version}.zip"
out.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for path in sorted(addon.rglob("*")):
        if path.is_file() and not path.name.startswith("."):
            # Fixed metadata makes local and CI artifacts byte-for-byte reproducible.
            info = zipfile.ZipInfo(str(path.relative_to(root)), (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            z.writestr(info, path.read_bytes())
with zipfile.ZipFile(out) as z:
    expected = {"XPIsland/" + name for name in [*files, "XPIsland.toc", "Bindings.xml", "LICENSE", "README.md", "media/rounded.tga", "media/cap.tga", "media/infinity.tga"]}
    assert set(z.namelist()) == expected, "Unexpected file in addon package"
    assert z.testzip() is None
    assert all(name.startswith("XPIsland/") for name in z.namelist())
    assert "XPIsland/XPIsland.toc" in z.namelist()
digest = hashlib.sha256(out.read_bytes()).hexdigest()
(root / "dist" / "SHA256SUMS").write_text(f"{digest}  {out.name}\n")
print(f"PASS: manifest, Lua syntax, bindings XML, TGA and ZIP integrity; {out.name} ({out.stat().st_size} bytes)")

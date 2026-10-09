"""Check the actual packaged alpha mask, not a substitute font glyph."""
from collections import deque
from pathlib import Path
import struct
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "scripts"))
from infinity_asset import generate

data = (root / "XPIsland/media/infinity.tga").read_bytes()
assert data == generate(), "packaged mask differs from its reproducible source"
w, h = struct.unpack_from("<HH", data, 12)
assert (w, h, data[2], data[16], data[17]) == (128, 64, 2, 32, 0x28)
alpha = data[21::4]
assert len(alpha) == w * h and min(alpha) == 0 and max(alpha) == 255
assert any(0 < a < 255 for a in alpha), "mask must contain antialiased edges"
assert all(data[i:i + 3] == b"\xff\xff\xff" for i in range(18, len(data), 4))
for y in range(h):
    for x in range(w):
        assert alpha[y*w+x] == alpha[y*w+w-1-x], "horizontal centering/symmetry"
        assert alpha[y*w+x] == alpha[(h-1-y)*w+x], "vertical centering/symmetry"
assert not any(alpha[x] or alpha[(h-1)*w+x] for x in range(w)), "top/bottom clipping"
assert not any(alpha[y*w] or alpha[y*w+w-1] for y in range(h)), "side clipping"

# At half coverage the two lobes must have two enclosed holes and form one
# connected stroke. This catches an empty, filled-in, broken or clipped symbol.
def components(foreground):
    remaining = {i for i, a in enumerate(alpha) if (a >= 128) == foreground}
    result = []
    while remaining:
        seed = remaining.pop()
        queue = deque([seed]); touches_edge = False
        while queue:
            i = queue.popleft(); x, y = i % w, i // w
            touches_edge |= x in (0, w-1) or y in (0, h-1)
            for xx, yy in ((x-1,y), (x+1,y), (x,y-1), (x,y+1)):
                neighbor = yy*w+xx
                if 0 <= xx < w and 0 <= yy < h and neighbor in remaining:
                    remaining.remove(neighbor); queue.append(neighbor)
        result.append(touches_edge)
    return result

assert components(True) == [False], "one connected stroke inside the canvas"
assert sorted(components(False)) == [False, False, True], "two open lobes"
print("PASS: packaged infinity pixels, reproducibility, alpha, symmetry, margins and two-loop topology")

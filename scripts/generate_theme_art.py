"""Generate the independent Forever theme's antialiased TGA artwork."""
from pathlib import Path
import math
import struct

ROOT = Path(__file__).resolve().parents[1] / "XPIsland" / "media"


def write(name, pixel):
    data = bytearray(18)
    data[2] = 2
    struct.pack_into("<HH", data, 12, 64, 64)
    data[16] = 32
    data[17] = 0x28
    offsets = (.125, .375, .625, .875)
    for y in range(64):
        for x in range(64):
            samples = [pixel(x + sx, y + sy) for sy in offsets for sx in offsets]
            # Stable accumulation keeps packaged bytes identical across Python versions.
            alpha = math.fsum(c[3] for c in samples) / 16
            rgb = [math.fsum(c[i] * c[3] for c in samples) / (16 * alpha) if alpha else 1 for i in range(3)]
            data.extend(round(max(0, min(1, c)) * 255) for c in (rgb[2], rgb[1], rgb[0], alpha))
    (ROOT / name).write_bytes(data)


def distance(x, y, radius):
    dx = max(radius - x, 0, x - (64 - radius))
    dy = max(radius - y, 0, y - (64 - radius))
    return radius - math.hypot(dx, dy) if dx and dy else min(x, y, 64 - x, 64 - y)


def chrome(x, y):
    d = distance(x, y, 16)
    if d < 0:
        return (1, 1, 1, 0)
    if d >= 16 / 3:
        return (.055, .044, .032, .84)
    # Dark silhouette, raised bronze face, then an inset shadow.
    factor = .40 if d < 1.25 else 1 if d < 3.8 else .38
    shade = 1 - y / 64
    rgb = tuple((lo + (hi - lo) * shade) * factor for lo, hi in zip((.31, .22, .12), (.83, .67, .40)))
    return (*rgb, 1)


def cap(x, y):
    return (1, 1, 1, 1 if distance(x, y, 64 / 7) >= 0 else 0)


def shading(x, y):
    t = int(y) / 63
    value = 1 if t < .5 else 0
    alpha = int((1 - 2 * t) * 85) if t < .5 else int((2 * t - 1) * 100)
    return (value, value, value, alpha / 255)


def cap_shading(x, y):
    # The same vertical gradient, clipped to the cap's antialiased silhouette.
    color = shading(x, y)
    return (*color[:3], color[3] if distance(x, y, 64 / 7) >= 0 else 0)


if __name__ == "__main__":
    write("forever-chrome.tga", chrome)
    write("soft-cap.tga", cap)
    write("theme-shading.tga", shading)
    write("soft-cap-shading.tga", cap_shading)

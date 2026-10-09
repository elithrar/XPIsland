"""Build the infinity alpha mask from a constant-width curve, without dependencies."""
from pathlib import Path
import math
import struct

WIDTH, HEIGHT, SAMPLES = 128, 64, 8


def generate():
    width, height = WIDTH * SAMPLES, HEIGHT * SAMPLES
    pixels = bytearray(width * height)
    # The display canvas is 1.5 x .75 font units; stroke is .12 font units.
    unit = width / 1.5
    radius = unit * .06
    points = [(width / 2 + unit * .55 * math.cos(i * math.tau / 512),
               height / 2 + unit * .24 * math.sin(2 * i * math.tau / 512))
              for i in range(513)]
    for (ax, ay), (bx, by) in zip(points, points[1:]):
        dx, dy = bx - ax, by - ay
        length2 = dx * dx + dy * dy
        for y in range(max(0, math.floor(min(ay, by) - radius)),
                       min(height, math.ceil(max(ay, by) + radius))):
            for x in range(max(0, math.floor(min(ax, bx) - radius)),
                           min(width, math.ceil(max(ax, bx) + radius))):
                px, py = x + .5 - ax, y + .5 - ay
                t = max(0, min(1, (px * dx + py * dy) / length2))
                if (px - t * dx) ** 2 + (py - t * dy) ** 2 <= radius ** 2:
                    pixels[y * width + x] = 1
    # Uncompressed BGRA, eight alpha bits, top-left origin. Transparent pixels
    # stay white too, avoiding dark fringes when the client filters the mask.
    data = bytearray(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0,
                                 WIDTH, HEIGHT, 32, 0x28))
    for y in range(HEIGHT):
        for x in range(WIDTH):
            coverage = sum(pixels[(y * SAMPLES + sy) * width + x * SAMPLES + sx]
                           for sy in range(SAMPLES) for sx in range(SAMPLES))
            data.extend((255, 255, 255, round(255 * coverage / SAMPLES ** 2)))
    return bytes(data)


if __name__ == "__main__":
    target = Path(__file__).resolve().parents[1] / "XPIsland/media/infinity.tga"
    target.write_bytes(generate())

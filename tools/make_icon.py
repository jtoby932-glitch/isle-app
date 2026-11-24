#!/usr/bin/env python3
"""Draws Isle's app icon (Pip on a yellow tile, 1024 px, opaque) and writes the asset catalog."""
import json
from pathlib import Path

from PIL import Image, ImageDraw

S = 1024
SS = 3
INK = (43, 40, 72)


def icon(path: Path):
    big = S * SS
    img = Image.new("RGB", (big, big), (255, 212, 92))
    d = ImageDraw.Draw(img)
    k = big / 120.0  # draw in Pip's 120-unit space, centred a little low

    def P(x, y):
        return (x * k, (y + 6) * k)

    def ell(cx, cy, rx, ry, fill, width=0):
        x0, y0 = P(cx - rx, cy - ry)
        x1, y1 = P(cx + rx, cy + ry)
        d.ellipse([x0, y0, x1, y1], fill=fill, outline=INK if width else None, width=int(width * k))

    # sea + island hint
    ell(60, 118, 70, 18, (143, 211, 240), 0)
    ell(60, 113, 44, 10, (166, 222, 143), 2.2)
    # feet
    ell(46, 104, 10, 6, (242, 118, 78), 2.6)
    ell(74, 104, 10, 6, (242, 118, 78), 2.6)
    # body + belly
    ell(60, 70, 40, 36, (255, 156, 122), 3.2)
    ell(60, 82, 23, 17, (255, 214, 196), 0)
    # sprout
    d.line([P(60, 34), P(60, 20)], fill=INK, width=int(3 * k))
    d.polygon([P(60, 22), P(50, 9), P(38, 12), P(36, 15), P(46, 26)], fill=(124, 203, 107), outline=INK)
    d.polygon([P(60, 22), P(70, 7), P(84, 10), P(86, 12), P(76, 25)], fill=(148, 218, 130), outline=INK)
    # happy eyes
    for ex in (46, 74):
        x0, y0 = P(ex - 6, 61)
        x1, y1 = P(ex + 6, 73)
        d.arc([x0, y0, x1, y1], start=200, end=340, fill=INK, width=int(3.4 * k))
    # cheeks
    ell(35, 76, 6.5, 4, (255, 160, 170), 0)
    ell(85, 76, 6.5, 4, (255, 160, 170), 0)
    # smile
    x0, y0 = P(54, 71)
    x1, y1 = P(66, 81)
    d.arc([x0, y0, x1, y1], start=20, end=160, fill=INK, width=int(3 * k))

    img = img.resize((S, S), Image.LANCZOS)
    img.save(path, "PNG")


def catalog(root: Path):
    assets = root / "Assets.xcassets"
    (assets / "AppIcon.appiconset").mkdir(parents=True, exist_ok=True)
    (assets / "AccentColor.colorset").mkdir(parents=True, exist_ok=True)
    info = {"author": "xcode", "version": 1}
    (assets / "Contents.json").write_text(json.dumps({"info": info}, indent=2))
    icon(assets / "AppIcon.appiconset" / "AppIcon-1024.png")
    (assets / "AppIcon.appiconset" / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "AppIcon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": info,
    }, indent=2))
    (assets / "AccentColor.colorset" / "Contents.json").write_text(json.dumps({
        "colors": [{"idiom": "universal", "color": {"color-space": "srgb", "components": {
            "red": "0.169", "green": "0.157", "blue": "0.282", "alpha": "1.000"}}}],
        "info": info,
    }, indent=2))


if __name__ == "__main__":
    catalog(Path(__file__).resolve().parent.parent / "Isle" / "Resources")
    print("icon written")

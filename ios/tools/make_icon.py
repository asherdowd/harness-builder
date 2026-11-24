#!/usr/bin/env python3
"""Regenerate the three app icon PNGs (light, dark, tinted) into the asset catalog.

Needs Pillow and rsvg-convert. Run from anywhere:
    python3 ios/tools/make_icon.py

Artwork: rounded plug, four pins (one empty), four wires, on the canvas grid.
Everything is aligned to the 64 px grid so the artwork has a three-row margin
(192 px) on every side.
"""
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

S = 1024
OUT = Path(__file__).resolve().parent.parent / "Harness Builder/Harness Builder/Assets.xcassets/AppIcon.appiconset"
WIRES = ["#c0645a", "#d9b45a", "#6aa57a", "#6290c0"]


def svg(BG, GRID, BODY, STROKE, PIN, RING, EMPTY, wires):
    tw, bh, cx, top = 616, 486, 512, 204
    bot = top + bh
    grid = "".join(
        f'<line x1="{i}" y1="0" x2="{i}" y2="{S}"/><line x1="0" y1="{i}" x2="{S}" y2="{i}"/>'
        for i in range(0, S + 1, 64)
    )
    xs = [cx - 135, cx + 135]
    ys = [top + bh / 2 - 108, top + bh / 2 + 108]
    pins = []
    for r, y in enumerate(ys):
        for c, x in enumerate(xs):
            if r == 1 and c == 1:
                pins.append(f'<circle cx="{x}" cy="{y}" r="62" fill="none" stroke="{EMPTY}" stroke-width="13" stroke-dasharray="20 20"/>')
            else:
                pins.append(f'<circle cx="{x}" cy="{y}" r="66" fill="{PIN}" stroke="{RING}" stroke-width="15"/>')
    leads = "".join(
        f'<line x1="{x}" y1="{bot - 4}" x2="{x}" y2="{bot + 120}" stroke="{col}" stroke-width="44" stroke-linecap="round"/>'
        for x, col in zip([cx - 240, cx - 80, cx + 80, cx + 240], wires)
    )
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">
<rect width="{S}" height="{S}" fill="{BG}"/><g stroke="{GRID}" stroke-width="3">{grid}</g>{leads}
<rect x="{cx - tw / 2}" y="{top}" width="{tw}" height="{bh}" rx="96" fill="{BODY}" stroke="{STROKE}" stroke-width="24"/>
{"".join(pins)}</svg>'''


VARIANTS = {
    "AppIcon-1024.png": ("#eceff3", "#d6dbe2", "#b0b6bd", "#4a525d", "#e2a355", "#1c1205", "#3a4049", WIRES),
    "AppIcon-1024-dark.png": ("#14181e", "#232932", "#1b1f26", "#7c8794", "#e2a355", "#040506", "#454c56", WIRES),
    "AppIcon-1024-tinted.png": ("#000000", "#1c1c1c", "#0e0e0e", "#9a9a9a", "#f2f2f2", "#000000", "#5a5a5a",
                                ["#b0b0b0", "#d0d0d0", "#8a8a8a", "#e6e6e6"]),
}

with tempfile.TemporaryDirectory() as tmp:
    for name, args in VARIANTS.items():
        src = Path(tmp) / (name + ".svg")
        src.write_text(svg(*args))
        dst = OUT / name
        subprocess.run(["rsvg-convert", "-w", str(S), "-h", str(S), "-b", args[0], str(src), "-o", str(dst)], check=True)
        Image.open(dst).convert("RGB").save(dst)  # opaque, no alpha channel (App Store requirement)
        print("wrote", dst)

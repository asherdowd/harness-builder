#!/usr/bin/env python3
"""Regenerate the three app icon PNGs (light, dark, tinted) into the asset catalog.

Needs Pillow and rsvg-convert. Run from anywhere:
    python3 ios/tools/make_icon.py

Artwork: a metallic plug with glossy amber pins (one empty, dashed) and four
colored wires on a gradient background. The default and dark icons share the
same dark-navy look; the tinted icon is greyscale.
"""
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

S = 1024
OUT = Path(__file__).resolve().parent.parent / "Harness Builder/Harness Builder/Assets.xcassets/AppIcon.appiconset"


def svg(bg1,bg2,glow,b1,b2,edge,pin1,pin2,ring,empty,wires,shadow):
    cx=512; top=170; bh=430; tw=730; bot=top+bh
    xs=[cx-170,cx+170]; ys=[top+bh/2-104, top+bh/2+104]
    pins=[]
    for r,y in enumerate(ys):
        for c,x in enumerate(xs):
            if r==1 and c==1:
                pins.append(f'<circle cx="{x}" cy="{y}" r="66" fill="{edge}" fill-opacity=".18"/><circle cx="{x}" cy="{y}" r="66" fill="none" stroke="{empty}" stroke-width="14" stroke-dasharray="22 22" stroke-linecap="round"/>')
            else:
                pins.append(f'<circle cx="{x}" cy="{y+5}" r="78" fill="#000" fill-opacity=".22"/>'
                            f'<circle cx="{x}" cy="{y}" r="76" fill="{ring}"/>'
                            f'<circle cx="{x}" cy="{y}" r="62" fill="url(#pin)"/>'
                            f'<ellipse cx="{x-16}" cy="{y-24}" rx="26" ry="14" fill="#fff" fill-opacity=".38" transform="rotate(-30 {x-16} {y-24})"/>')
    leads=""
    for x,col in zip([cx-270,cx-90,cx+90,cx+270],wires):
        leads+=(f'<line x1="{x}" y1="{bot-40}" x2="{x}" y2="{bot+250}" stroke="#000" stroke-opacity=".25" stroke-width="66" stroke-linecap="round" transform="translate(0 8)" filter="url(#blur)"/>'
                f'<line x1="{x}" y1="{bot-40}" x2="{x}" y2="{bot+250}" stroke="{col}" stroke-width="64" stroke-linecap="round"/>'
                f'<line x1="{x-14}" y1="{bot+10}" x2="{x-14}" y2="{bot+225}" stroke="#fff" stroke-opacity=".30" stroke-width="12" stroke-linecap="round"/>')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">
<defs>
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{bg1}"/><stop offset="1" stop-color="{bg2}"/></linearGradient>
<radialGradient id="glow" cx=".5" cy=".3" r=".7"><stop offset="0" stop-color="{glow}" stop-opacity=".35"/><stop offset="1" stop-color="{glow}" stop-opacity="0"/></radialGradient>
<linearGradient id="body" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{b1}"/><stop offset="1" stop-color="{b2}"/></linearGradient>
<radialGradient id="pin" cx=".4" cy=".35" r=".8"><stop offset="0" stop-color="{pin1}"/><stop offset="1" stop-color="{pin2}"/></radialGradient>
<filter id="blur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="10"/></filter>
<filter id="blur2" x="-20%" y="-20%" width="140%" height="150%"><feGaussianBlur stdDeviation="22"/></filter>
</defs>
<rect width="{S}" height="{S}" fill="url(#bg)"/><rect width="{S}" height="{S}" fill="url(#glow)"/>
{leads}
<rect x="{cx-tw/2}" y="{top+30}" width="{tw}" height="{bh}" rx="120" fill="#000" fill-opacity="{shadow}" filter="url(#blur2)"/>
<rect x="{cx-tw/2}" y="{top}" width="{tw}" height="{bh}" rx="120" fill="{edge}"/>
<rect x="{cx-tw/2+10}" y="{top+8}" width="{tw-20}" height="{bh-24}" rx="110" fill="url(#body)"/>
<rect x="{cx-tw/2+28}" y="{top+20}" width="{tw-56}" height="70" rx="60" fill="#fff" fill-opacity=".22"/>
{"".join(pins)}</svg>'''
DARK = ("#1d2433", "#090c12", "#6f8fc0", "#d9dee6", "#8f98a6", "#06080c", "#f4b65e", "#c97a20", "#0a0603", "#cfd6e0",
        ["#e65448", "#eab944", "#52ad77", "#5aa3e6"], .5)
VARIANTS = {
    "AppIcon-1024.png": DARK,
    "AppIcon-1024-dark.png": DARK,
    "AppIcon-1024-tinted.png": ("#1a1a1a", "#000000", "#ffffff", "#f0f0f0", "#a8a8a8", "#000000", "#ffffff", "#bdbdbd", "#000000", "#d0d0d0",
                                ["#8c8c8c", "#cfcfcf", "#a6a6a6", "#e8e8e8"], .5),
}

with tempfile.TemporaryDirectory() as tmp:
    for name, args in VARIANTS.items():
        src = Path(tmp) / (name + ".svg")
        src.write_text(svg(*args))
        dst = OUT / name
        subprocess.run(["rsvg-convert", "-w", str(S), "-h", str(S), str(src), "-o", str(dst)], check=True)
        Image.open(dst).convert("RGB").save(dst)  # opaque, no alpha channel (App Store requirement)
        print("wrote", dst)

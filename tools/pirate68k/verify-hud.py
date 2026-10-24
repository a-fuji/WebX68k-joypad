#!/usr/bin/env python3
"""Compare rendered HUD glyph pixels to a state captured through MCP."""
import argparse
import json
from pathlib import Path
from PIL import Image
from art import GLYPHS

ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('screenshot', type=Path)
ap.add_argument('state', type=Path)
a = ap.parse_args()
im = Image.open(a.screenshot).convert('RGB')
s = json.loads(a.state.read_text())
assert im.size == (256, 256), im.size
values = [(40, 4, f'{s["score"]:05d}'), (222, 4, str(s['life'])), (36, 245, str(s['bombs'])), (100, 245, str(s['stage']))]
for x, y, value in values:
    for i, ch in enumerate(value):
        rows = [''.join('1' if min(im.getpixel((x + i*6 + dx, y + dy))) > 200 else '0' for dx in range(5)) for dy in range(7)]
        assert rows == GLYPHS[ch], f'HUD mismatch at x={x + i*6}: expected {ch}, got {rows}'
print(json.dumps({'result': 'PASS', 'score': s['score'], 'life': s['life'], 'bombs': s['bombs'], 'stage': s['stage']}))

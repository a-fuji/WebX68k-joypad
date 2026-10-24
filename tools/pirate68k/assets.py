#!/usr/bin/env python3
"""Convert the supplied title to X68000 GRB-I words, without copying the source."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, __version__ as pillow_version

ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('image', type=Path)
ap.add_argument('--font', type=Path, default=Path('/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc'))
ap.add_argument('--output', type=Path, required=True)
a = ap.parse_args()
im = Image.open(a.image).convert('RGB').resize((256, 256), Image.Resampling.LANCZOS)
d = ImageDraw.Draw(im)
d.rectangle((0, 0, 255, 33), fill=(7, 9, 22))
font_path = str(a.font)
if not a.font.is_file():
    ap.error('Japanese font not found: specify --font /path/to/font.ttf')
f = ImageFont.truetype(font_path, 24)
d.text((42, 2), '海賊王ゲーム', font=f, fill=(255, 211, 99), stroke_width=1, stroke_fill=(50, 20, 0))
d.rectangle((0, 220, 255, 255), fill=(7, 9, 22))
d.text((58, 225), 'Z / TRIGGER 1 : START', fill=(255, 227, 154))
d.text((52, 241), 'ARROWS  Z:SHOT  X:BOMB', fill=(164, 207, 240))
a.output.parent.mkdir(parents=True, exist_ok=True)
im.save(a.output.with_suffix('.png'))
im.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(a.output.with_suffix('.indexed.png'), bits=8)
a.output.with_suffix('.json').write_text(json.dumps({'source_sha256': hashlib.sha256(a.image.read_bytes()).hexdigest(), 'dimensions':[256,256], 'font':font_path, 'font_sha256':hashlib.sha256(a.font.read_bytes()).hexdigest(), 'pillow':pillow_version}, indent=2)+'\n')

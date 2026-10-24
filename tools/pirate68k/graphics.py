#!/usr/bin/env python3
"""Convert the approved raster art to X68000 PCG tiles and indexed backgrounds."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'games/pirate68k/assets'
# Bounding regions in the generated atlas, not an assumed perfectly regular grid.
REGIONS = [
    ('luffy_idle', (70, 50, 300, 345), 32, 1),
    ('luffy_left', (420, 50, 650, 345), 32, 1),
    ('luffy_right', (790, 50, 1020, 345), 32, 1),
    ('luffy_shot', (1170, 35, 1395, 345), 32, 1),
    ('grunt_idle', (15, 380, 335, 700), 32, 2),
    ('grunt_step', (390, 380, 690, 700), 32, 2),
    ('zoro_art', (700, 375, 1095, 700), 64, 3),
    ('sanji_art', (1100, 365, 1448, 700), 64, 4),
    ('bigmom_art', (0, 700, 405, 1060), 96, 5),
    ('kaido_art', (405, 700, 825, 1060), 96, 6),
    ('shot_art', (900, 730, 1065, 1030), 16, 7),
    ('orb_art', (1170, 755, 1400, 990), 16, 8),
]

def color_word(rgb):
    r, g, b = rgb[:3]
    return ((g >> 3) << 11) | ((r >> 3) << 6) | ((b >> 3) << 1) | 1

def pack_tile(im, x, y):
    """XSP .SP order: 8x8 quadrants TL, BL, TR, BR; high nibble first."""
    out = bytearray()
    for qx, qy in [(0, 0), (0, 8), (8, 0), (8, 8)]:
        for row in range(8):
            for col in range(0, 8, 2):
                out.append((im.getpixel((x + qx + col, y + qy + row)) << 4) |
                           im.getpixel((x + qx + col + 1, y + qy + row)))
    return out

def main(output):
    output.mkdir(parents=True, exist_ok=True)
    atlas = Image.open(ASSETS / 'characters-source.png').convert('RGBA')
    cropped = {}
    for name, box, size, group in REGIONS:
        im = atlas.crop(box)
        mask = im.getchannel('A').point(lambda a: 255 if a >= 160 else 0)
        im.putalpha(mask)
        im = im.crop(mask.getbbox())
        cropped[name] = im
    images = {}
    for name, box, size, group in REGIONS:
        im = cropped[name]
        # One scale across each animation family keeps the body size stable.
        family = [cropped[n] for n, _, _, g in REGIONS if g == group]
        ratio = (size - 2) / max(max(v.size) for v in family)
        small = im.resize((max(1, round(im.width * ratio)), max(1, round(im.height * ratio))), Image.Resampling.LANCZOS)
        small.putalpha(small.getchannel('A').point(lambda a: 255 if a >= 128 else 0))
        tile = Image.new('RGBA', (size, size))
        tile.paste(small, ((size - small.width) // 2, size - small.height - 1))
        images[name] = (tile, group)
    # A readable, expanding slash trail independent of the helper's body.
    for name, group, colors in [('slash_art', 9, ['#29b877', '#9cffd4', '#ffffff']),
                                ('flame_art', 10, ['#e64113', '#ffad27', '#fff1a2'])]:
        im = Image.new('RGBA', (96, 64)); draw = ImageDraw.Draw(im)
        for i, col in enumerate(colors):
            draw.arc((2+i, 3+i, 93-i, 60-i), 195, 355, fill=col, width=4-i)
            draw.arc((4+i, 4+i, 90-i, 59-i), 15, 175, fill=col, width=4-i)
        images[name] = (im, group)
    palettes = bytearray(); indexed = {}
    for group in range(1, 11):
        members = [(n, im) for n, (im, g) in images.items() if g == group]
        colors = [rgb[:3] for _, im in members for rgb in im.get_flattened_data() if rgb[3]]
        strip = Image.new('RGB', (len(colors), 1)); strip.putdata(colors)
        pal = strip.quantize(colors=15, method=Image.Quantize.MEDIANCUT)
        rgbpal = pal.getpalette()[:45]
        rgbpal += rgbpal[:3] * ((45-len(rgbpal))//3)
        ref = Image.new('P', (1, 1)); ref.putpalette(rgbpal + rgbpal[:3] * ((768-len(rgbpal))//3))
        palettes += struct.pack('>16H', 0, *[color_word(rgbpal[i:i+3]) for i in range(0, 45, 3)])
        for name, im in members:
            q = im.convert('RGB').quantize(palette=ref, dither=Image.Dither.NONE)
            data = [(p + 1 if p < 15 else 1) if a else 0 for p, a in zip(q.get_flattened_data(), im.getchannel('A').get_flattened_data())]
            out = Image.new('P', im.size); out.putdata(data)
            out.putpalette([0, 0, 0] + rgbpal + [0] * (768-48))
            out.info['transparency'] = 0
            out.save(output / (name + '.png'))
            indexed[name] = out
    sp = bytearray(); descriptors = []; manifest = []
    for name, (im, group) in images.items():
        q = indexed[name]; entries = []
        for y in range(0, im.height, 16):
            for x in range(0, im.width, 16):
                tile = q.crop((x, y, x+16, y+16))
                if not tile.getbbox(): continue
                pattern = len(sp) // 128
                sp += pack_tile(q, x, y)
                entries.append((x-im.width//2, y-im.height//2, pattern, (group << 8) | 0x30))
        descriptors += [name + ':', f'        dc.w {len(entries)}']
        descriptors += ['        dc.w ' + ','.join(str(v) for v in row) for row in entries]
        manifest.append(dict(name=name, width=im.width, height=im.height, palette=group, tiles=len(entries)))
    (output / 'SPRITES.SP').write_bytes(sp)
    (output / 'SPRITES.PAL').write_bytes(palettes)
    (output / 'GRAPHICS.INC').write_text('* Generated by graphics.py\nSP_COUNT equ ' + str(len(sp)//128) + '\n' + '\n'.join(descriptors) + '\n')
    bg = Image.open(ASSETS / 'backgrounds-source.png').convert('RGB')
    for i in range(2):
        im = bg.crop((i*bg.width//2, 0, (i+1)*bg.width//2, bg.height)).resize((256, 256), Image.Resampling.LANCZOS)
        draw = ImageDraw.Draw(im)
        draw.rectangle((0, 0, 255, 15), fill='#10141f')
        draw.rectangle((0, 240, 255, 255), fill='#10141f')
        q = im.quantize(colors=256, dither=Image.Dither.NONE)
        q.save(output / f'BG{i+1}.png')
        (output / f'BG{i+1}.BIN').write_bytes(q.tobytes())
        pal = q.getpalette()
        (output / f'BG{i+1}.PAL').write_bytes(struct.pack('>256H', *[color_word(pal[n:n+3]) for n in range(0, 768, 3)]))
    (output / 'graphics.json').write_text(json.dumps(dict(sprites=manifest, patterns=len(sp)//128,
        source_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in ASSETS.glob('*-source.png')}), indent=2)+'\n')
    # Exact native-size preview; only nearest-neighbor enlargement for inspection.
    preview = Image.new('RGB', (512, 256))
    for i in range(2):
        preview.paste(Image.open(output/f'BG{i+1}.png').convert('RGB'), (i*256, 0))
        for name, xy in [('luffy_shot', (112, 194)), ('grunt_idle', (50, 70))] if i == 0 else [('luffy_left', (72, 194)), ('kaido_art', (80, 28))]:
            im = indexed[name].convert('RGBA'); preview.paste(im, (xy[0]+i*256, xy[1]), im)
    preview.resize((1024, 512), Image.Resampling.NEAREST).save(output/'native-preview.png')
    print(json.dumps(dict(patterns=len(sp)//128, sprite_bytes=len(sp), output=str(output))))

if __name__ == '__main__':
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, default=ROOT/'_local/pirate68k/graphics')
    main(ap.parse_args().output)

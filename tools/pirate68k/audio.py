#!/usr/bin/env python3
"""Extract only the temporary MaidLand audio inputs; never alter source media."""
import argparse
import hashlib
import json
from pathlib import Path
import re
from xdf import Disk, ROOT

MUSIC_LIMIT = 32768
SE_LIMIT = 1024


def fm_sequence(source, label):
    match = re.search(r'^' + re.escape(label) + r':(.*?)(?=^\w+:|\Z)', source, re.M | re.S)
    if not match:
        raise ValueError('FM sequence not found: ' + label)
    lines = re.findall(r'^\s*dc\.b\s+([^\r\n]+)', match[1], re.M | re.I)
    data = bytes(int(token.strip().removeprefix('$'), 16) for line in lines for token in line.split('*')[0].split(','))
    if not data.startswith(b'\0\1') or not data.endswith(b'\xff'):
        raise ValueError('Expected one-track MaidLand FM sequence: ' + label)
    return data


def validate(name, data):
    limit = MUSIC_LIMIT if name.endswith('.ZMD') else SE_LIMIT
    if not 8 <= len(data) <= limit:
        raise ValueError(f'{name}: expected 8..{limit} bytes, got {len(data)}')
    if name.endswith('.ZMD') and (data[:7] != b'\x10ZmuSiC' or data[7] >= 0x30):
        raise ValueError(name + ': expected Z-MUSIC v2 ZMD header')
    if name.endswith('.SE') and data[:2] != b'\0\1':
        raise ValueError(name + ': expected one-track SE data')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--maid-disk', type=Path, required=True)
    ap.add_argument('--maid-source', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    config = json.loads((ROOT / 'games/pirate68k/audio.json').read_text())
    disk = Disk(bytearray(args.maid_disk.read_bytes()))
    source = args.maid_source.read_bytes().decode('cp932')
    args.output.mkdir(parents=True, exist_ok=True)
    records = []
    def save(name, data, origin):
        (args.output / name).write_bytes(data)
        records.append(dict(file=name, size=len(data), sha256=hashlib.sha256(data).hexdigest(), source=origin))
    for name, path in config['music'].items():
        data = disk.read(path)
        validate(name, data)
        save(name, data, 'MaidLand XDF:' + path)
    for name, label in config['fm_effects'].items():
        data = fm_sequence(source, label)
        validate(name, data)
        save(name, data, 'MaidLand src/SOUND.S:' + label)
    save('SFX.ZPD', disk.read(config['pcm_bank']), 'MaidLand XDF:' + config['pcm_bank'])
    save('ZMSC.X', disk.read(config['driver']), 'MaidLand XDF:' + config['driver'])
    (args.output / 'AUDIO.INC').write_text(
        '* Generated from games/pirate68k/audio.json\n'
        f'PCM_BOMB equ {config["pcm_bomb_note"]}\n'
        f'PCM_BOSS equ {config["pcm_boss_note"]}\n'
        f'PCM_MODE equ ${config["pcm_mode"]}\n')
    result = dict(temporary_data=True, files=records)
    (args.output / 'audio.manifest.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()

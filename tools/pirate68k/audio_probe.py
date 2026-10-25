#!/usr/bin/env python3
"""Derive a local test disk that isolates actual FM and ZPD output."""
from pathlib import Path
from xdf import Disk, emit

root = Path('_local/pirate68k')
source = Disk(bytearray((root / 'release-audio.xdf').read_bytes()))
tone = source.read('/AUDIO/TONE.ZMD')
probe = Disk.blank()
for entry in source.manifest()['files']:
    path = entry['path']
    data = source.read(path)
    if path.endswith('.ZMD'):
        data = tone  # MaidLand's silent timbre initializer, no BGM notes.
    elif path == '/AUDIO/BOMB.SE':
        data = bytes.fromhex('0001000000020007ff')  # One empty FM8 track.
    probe.put(path, data)
emit(probe, root / 'audio-effects-probe.xdf', [
    dict(test_only=True, source_sha256=source.manifest()['sha256'],
         substitutions=['All ZMD -> TONE.ZMD', 'BOMB.SE -> empty FM8 track'])])

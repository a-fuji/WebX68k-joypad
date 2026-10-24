#!/usr/bin/env python3
"""Deterministic local XDF packager; external media are opened read-only."""
import argparse
import hashlib
import json
import mmap
from pathlib import Path
import struct
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'x68'))
from fatput import Fat12, to_8_3

ROOT = Path(__file__).resolve().parents[2]


def sha(data):
    return hashlib.sha256(data).hexdigest()


class Disk(Fat12):
    def __init__(self, image):
        super().__init__(image)
        if len(image) != 1261568 or self.bps != 1024 or self.spc != 1:
            raise ValueError('Expected standard 1232 KiB XDF')
        self.dirs = {'/': list(range(self.root_start, self.root_start + self.root_entries * 32, 32))}

    @classmethod
    def blank(cls):
        # Same standard 2HD geometry as src/api/fat.ts:createFormattedFd.
        b = bytearray(1261568)
        b[:11] = b'\x60\x3c\x90X68IPL30'
        struct.pack_into('<HBHBHHBHHH', b, 11, 1024, 1, 1, 2, 192, 1232, 0xfe, 2, 8, 2)
        d = cls(b)
        d.img[d.fat_start:d.fat_start + 3] = b'\xfe\xff\xff'
        other = d.fat_start + d.spf * d.bps
        d.img[other:other + 3] = b'\xfe\xff\xff'
        return d

    def chain(self, c):
        seen = set()
        while c < 0xff8:
            if not 2 <= c < self.total_clusters or c in seen:
                raise ValueError('Invalid/cyclic FAT chain')
            seen.add(c)
            yield c
            c = self.get_fat(c)

    def entries(self, path='/'):
        if path == '/':
            offsets = self.dirs['/']
        else:
            parent, _, name = path.rstrip('/').rpartition('/')
            e = next(e for e in self.entries(parent or '/') if e['name'].upper() == name.upper())
            offsets = [self.cluster_offset(c) + i for c in self.chain(e['cluster']) for i in range(0, self.cluster_bytes, 32)]
        for off in offsets:
            e = self.img[off:off + 32]
            if not e[0]:
                break
            if e[0] == 229 or e[11] & 8 or e[0] == 46:
                continue
            name = e[:8].decode('shift_jis').rstrip()
            ext = e[8:11].decode('shift_jis').rstrip()
            yield dict(name=name + ('.' + ext if ext else ''), directory=bool(e[11] & 16), cluster=struct.unpack_from('<H', e, 26)[0], size=struct.unpack_from('<I', e, 28)[0])

    def read(self, path):
        parent, _, name = path.rstrip('/').rpartition('/')
        e = next(e for e in self.entries(parent or '/') if e['name'].upper() == name.upper())
        return b''.join(self.img[self.cluster_offset(c):self.cluster_offset(c) + self.cluster_bytes] for c in self.chain(e['cluster']))[:e['size']]

    def put(self, path, payload, directory=False):
        parent, _, name = path.upper().rpartition('/')
        parent = parent or '/'
        if parent not in self.dirs:
            self.put(parent, b'', True)
        name11 = to_8_3(name)
        offsets = self.dirs[parent]
        if any(self.img[o:o + 11] == name11 for o in offsets):
            raise ValueError('Duplicate output: ' + path)
        off = next(o for o in offsets if self.img[o] == 0)
        needed = max(1, (len(payload) + self.cluster_bytes - 1) // self.cluster_bytes)
        clusters = self.free_clusters(needed)
        for i, c in enumerate(clusters):
            self.set_fat(c, clusters[i + 1] if i + 1 < len(clusters) else 0xfff)
            p = self.cluster_offset(c)
            self.img[p:p + self.cluster_bytes] = payload[i * self.cluster_bytes:(i + 1) * self.cluster_bytes].ljust(self.cluster_bytes, b'\0')
        entry = bytearray(32)
        entry[:11] = name11
        entry[11] = 16 if directory else 32
        struct.pack_into('<HHHI', entry, 22, 0, 33, clusters[0], 0 if directory else len(payload))  # 1980-01-01
        self.img[off:off + 32] = entry
        if directory:
            p = self.cluster_offset(clusters[0])
            for i, (n, cluster) in enumerate([(b'.          ', clusters[0]), (b'..         ', self._dir_cluster(parent))]):
                dot = bytearray(entry)
                dot[:11] = n
                struct.pack_into('<H', dot, 26, cluster)
                self.img[p + i * 32:p + (i + 1) * 32] = dot
            self.dirs[path.upper()] = list(range(p + 64, p + self.cluster_bytes, 32))

    def _dir_cluster(self, path):
        return 0 if path == '/' else (self.dirs[path][0] - 64 - self.data_start) // self.cluster_bytes + 2

    def manifest(self):
        result = []
        def walk(p):
            for e in self.entries(p):
                path = p.rstrip('/') + '/' + e['name']
                if e['directory']:
                    walk(path)
                else:
                    b = self.read(path)
                    result.append(dict(path=path, size=len(b), sha256=sha(b)))
        walk('/')
        free = sum(self.get_fat(c) == 0 for c in range(2, self.total_clusters)) * self.cluster_bytes
        return dict(format='X68000 2HD FAT12', bytes=len(self.img), sha256=sha(self.img), used_bytes=sum(x['size'] for x in result), allocated_bytes=(self.total_clusters - 2) * self.cluster_bytes - free, filesystem_bytes=self.data_start, free_bytes=free, files=result)


class Hds:
    """Read the first Human68k FAT16 partition of X68SCSI1; never mount/write it."""
    def __init__(self, path):
        self.file = open(path, 'rb')
        self.b = mmap.mmap(self.file.fileno(), 0, access=mmap.ACCESS_READ)
        if self.b[:8] != b'X68SCSI1' or self.b[0x800:0x804] != b'X68K':
            raise ValueError('Expected X68SCSI1 image')
        # Partition starts are counted in 1 KiB blocks, from the image start in this X68SCSI1 layout.
        start = struct.unpack_from('>I', self.b, 0x818)[0]
        self.o = start * 1024
        o = self.o
        self.bps = struct.unpack_from('>H', self.b, o + 0x12)[0]
        self.cb = self.b[o + 0x14] * self.bps
        self.fat = o + struct.unpack_from('>H', self.b, o + 0x16)[0] * self.bps
        self.root = self.fat + self.b[o + 0x15] * self.b[o + 0x1d] * self.bps
        self.rootsize = struct.unpack_from('>H', self.b, o + 0x18)[0] * 32
        self.data = self.root + self.rootsize
        if self.bps != 1024 or self.cb != 16384:
            raise ValueError('Unsupported HDS geometry')

    def chain(self, c):
        out = bytearray()
        seen = set()
        while 2 <= c < 0xfff8:
            if c in seen or self.data + (c - 1) * self.cb > len(self.b):
                raise ValueError('Invalid HDS FAT chain')
            seen.add(c)
            out += self.b[self.data + (c - 2) * self.cb:self.data + (c - 1) * self.cb]
            c = struct.unpack_from('>H', self.b, self.fat + c * 2)[0]
        return bytes(out)

    def read(self, path):
        raw = self.b[self.root:self.root + self.rootsize]
        for name in path.strip('/').upper().split('/'):
            target = to_8_3(name)
            for i in range(0, len(raw), 32):
                e = raw[i:i + 32]
                if e[:11].upper() == target:
                    c, size = struct.unpack_from('<HI', e, 26)
                    raw = self.chain(c)
                    if not e[11] & 16:
                        raw = raw[:size]
                    break
            else:
                raise ValueError('File absent in HDS: ' + path)
        return raw


def emit(disk, output, provenance):
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(disk.img)
    manifest = disk.manifest()
    manifest['inputs'] = provenance
    output.with_suffix('.manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    output.with_suffix('.sha256').write_text(f'{manifest["sha256"]}  {output.name}\n')
    print(json.dumps({k: v for k, v in manifest.items() if k != 'files'}, indent=2))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest='command', required=True)
    dev = sub.add_parser('dev')
    dev.add_argument('--title', type=Path, required=True)
    dev.add_argument('--hds', type=Path, required=True)
    dev.add_argument('--tool-disk', type=Path, required=True, help='Read-only Dev68K.XDF containing /XSP2lib.o')
    dev.add_argument('--graphics', type=Path, default=ROOT / '_local/pirate68k/graphics')
    dev.add_argument('--output', type=Path, required=True)
    rel = sub.add_parser('release')
    rel.add_argument('--executable', type=Path, required=True)
    rel.add_argument('--output', type=Path, required=True)
    ls = sub.add_parser('list')
    ls.add_argument('image', type=Path)
    get = sub.add_parser('get')
    get.add_argument('image', type=Path)
    get.add_argument('path')
    get.add_argument('output', type=Path)
    args = ap.parse_args()
    if args.command in ('list', 'get'):
        d = Disk(bytearray(args.image.read_bytes()))
        if args.command == 'list':
            print(json.dumps(d.manifest(), indent=2))
        else:
            args.output.write_bytes(d.read(args.path))
        return
    d = Disk.blank()
    provenance = []
    if args.command == 'dev':
        h = Hds(args.hds)
        for name in ['HAS060.X', 'HLK.X']:
            data = h.read('/BIN/' + name)
            d.put('/BIN/' + name, data)
            provenance.append(dict(source='HDS:/BIN/' + name, sha256=sha(data), redistribution='unreviewed; local only'))
        library = Disk(bytearray(args.tool_disk.read_bytes())).read('/XSP2lib.o')
        d.put('/BIN/XSP2LIB.O', library)
        provenance.append(dict(source='Dev68K.XDF:/XSP2lib.o', sha256=sha(library)))
        for p in sorted((ROOT / 'games/pirate68k').glob('*')):
            if p.suffix.upper() in ('.S', '.INC'):
                d.put('/SRC/' + p.name.upper(), p.read_bytes().replace(b'\r\n', b'\n').replace(b'\n', b'\r\n'))
        d.put('/BUILD.BAT', (ROOT / 'games/pirate68k/BUILD.BAT').read_bytes().replace(b'\r\n', b'\n').replace(b'\n', b'\r\n'))
        d.put('/SRC/TITLE.RAW', args.title.read_bytes())
        for name in ['GRAPHICS.INC', 'SPRITES.SP', 'SPRITES.PAL', 'BG1.BIN', 'BG1.PAL', 'BG2.BIN', 'BG2.PAL']:
            d.put('/SRC/' + name, (args.graphics / name).read_bytes())
        d.put('/OUT', b'', True)
    else:
        data = args.executable.read_bytes()
        if data[:2] != b'HU' or len(data) < 64:
            raise ValueError('Expected linked Human68k .X executable')
        d.put('/PIRATE.X', data)
    d.put('/GO.BAT', b'ECHO OFF\r\nPIRATE.X\r\n' if args.command == 'release' else b'ECHO OFF\r\nCD \\OUT\r\nPIRATE.X\r\n')
    d.put('/README.TXT', b'PIRATE68K - FAN GAME PROTOTYPE\r\nBoot Human68k in A:, this disk in B:.\r\nB: then GO (development: BUILD first).\r\nArrows: move; Z: shot; X: bomb; R: restart; ESC: quit.\r\nUnofficial fan work. No original anime/game assets.\r\n')
    emit(d, args.output, provenance)


if __name__ == '__main__':
    main()

"""Host image integrity tests. Run with Python >= 3.10."""
import unittest
from xdf import Disk


class XdfTests(unittest.TestCase):
    def test_large_file_and_directories(self):
        d = Disk.blank()
        data = bytes(range(256)) * 777
        d.put('/SRC/BIG.BIN', data)
        d.put('/OUT/EMPTY.TXT', b'')
        loaded = Disk(bytearray(d.img))
        self.assertEqual(loaded.read('/src/big.bin'), data)
        self.assertEqual(loaded.read('/OUT/EMPTY.TXT'), b'')
        self.assertEqual(len(loaded.manifest()['files']), 2)

    def test_deterministic_bytes(self):
        outputs = []
        for _ in range(2):
            d = Disk.blank()
            d.put('/ONE/TWO/TEST.BIN', b'hello' * 1000)
            outputs.append(d.img)
        self.assertEqual(*outputs)

    def test_fat_mirrors(self):
        d = Disk.blank()
        d.put('/A/B.BIN', b'x' * 5001)
        n = d.spf * d.bps
        self.assertEqual(d.img[d.fat_start:d.fat_start+n], d.img[d.fat_start+n:d.fat_start+2*n])

    def test_duplicate_is_rejected(self):
        d = Disk.blank()
        d.put('/DATA.TXT', b'a')
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            d.put('/DATA.TXT', b'b')

    def test_capacity(self):
        with self.assertRaises(RuntimeError):
            Disk.blank().put('/HUGE.BIN', bytes(1261568))

    def test_cyclic_chain(self):
        d = Disk.blank()
        d.put('/LOOP.BIN', b'x')
        c = next(d.entries())['cluster']
        d.set_fat(c, c)
        with self.assertRaisesRegex(ValueError, 'cyclic'):
            d.read('/LOOP.BIN')

    def test_geometry_is_rejected(self):
        with self.assertRaises(ValueError):
            Disk(bytearray(512))

    def test_manifest_capacity_and_hashes(self):
        d = Disk.blank()
        d.put('/PIRATE.X', b'HU' + bytes(3000))
        m = d.manifest()
        self.assertEqual(m['bytes'], 1261568)
        self.assertEqual(m['used_bytes'], 3002)
        self.assertEqual(m['files'][0]['path'], '/PIRATE.X')
        self.assertEqual(len(m['sha256']), 64)
        self.assertGreater(m['free_bytes'], 1200000)
        self.assertEqual(m['allocated_bytes'] + m['filesystem_bytes'] + m['free_bytes'], m['bytes'])


if __name__ == '__main__':
    unittest.main()

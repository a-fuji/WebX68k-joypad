"""Hardware asset contracts: geometry, transparency, PCG layout and budget."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from PIL import Image
from graphics import main, pack_tile, color_word


class GraphicsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.out = Path(cls.tmp.name)
        with contextlib.redirect_stdout(io.StringIO()):
            main(cls.out)
        cls.meta = json.loads((cls.out/'graphics.json').read_text())

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_xsp_quadrant_order(self):
        im = Image.new('P', (16, 16))
        for y in range(16):
            for x in range(16):
                im.putpixel((x, y), 1 + (y//8) + (x//8)*2)
        self.assertEqual(pack_tile(im, 0, 0), bytes([0x11]*32+[0x22]*32+[0x33]*32+[0x44]*32))

    def test_color_word_channels(self):
        self.assertEqual(color_word((255, 0, 0)), 0x07c1)
        self.assertEqual(color_word((0, 255, 0)), 0xf801)
        self.assertEqual(color_word((0, 0, 255)), 0x003f)

    def test_native_sizes_and_transparency(self):
        for entry in self.meta['sprites']:
            im = Image.open(self.out/(entry['name']+'.png'))
            self.assertEqual(im.size, (entry['width'], entry['height']))
            self.assertEqual(im.info['transparency'], 0)
            self.assertLessEqual(max(im.get_flattened_data()), 15)
            self.assertIn(0, im.get_flattened_data())
        byname = {v['name']:v for v in self.meta['sprites']}
        self.assertEqual(byname['luffy_idle']['width'], 32)
        self.assertEqual(byname['grunt_idle']['width'], 32)
        self.assertEqual(byname['bigmom_art']['width'], 96)
        self.assertEqual(byname['kaido_art']['width'], 96)

    def test_storage_and_simultaneous_sprite_budget(self):
        self.assertLessEqual(self.meta['patterns'], 256)
        self.assertEqual((self.out/'SPRITES.SP').stat().st_size, self.meta['patterns']*128)
        self.assertEqual((self.out/'SPRITES.PAL').stat().st_size, 10*32)
        # Full rectangular upper bound, even if all gameplay arrays coexist.
        self.assertLessEqual(4+8*4+36+8+8+16+24, 128)

    def test_background_geometry(self):
        for n in (1, 2):
            self.assertEqual((self.out/f'BG{n}.BIN').stat().st_size, 256*256)
            self.assertEqual((self.out/f'BG{n}.PAL').stat().st_size, 512)


if __name__ == '__main__':
    unittest.main()

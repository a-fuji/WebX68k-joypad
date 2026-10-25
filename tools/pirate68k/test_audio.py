"""Audio input contract: reject invalid replacements before producing a disk."""
import unittest
from audio import fm_sequence, validate


class AudioTests(unittest.TestCase):
    def test_select_only_named_sequence(self):
        source = 'se12:\n dc.b $00,$01,$00,$00,$00,$02,$00,$07,$ff\n .even\nse13:\n dc.b $11\n'
        self.assertEqual(fm_sequence(source, 'se12'), bytes.fromhex('0001000000020007ff'))
        with self.assertRaises(ValueError):
            fm_sequence(source, 'se1')

    def test_reject_unterminated_fm(self):
        with self.assertRaises(ValueError):
            fm_sequence('se0:\n dc.b $00,$01,$00,$02\n', 'se0')

    def test_zmd_header_and_size(self):
        validate('STAGE1.ZMD', b'\x10ZmuSiC\x20\xff')
        for data in [b'not a ZMD', b'\x10ZmuSiC\x30', b'\x10ZmuSiC\x20' + bytes(32768)]:
            with self.assertRaises(ValueError):
                validate('STAGE1.ZMD', data)

    def test_fm_track_count_and_size(self):
        validate('SHOT.SE', bytes.fromhex('0001000000020007ff'))
        for data in [bytes.fromhex('0002000000020007ff'), bytes(1025)]:
            with self.assertRaises(ValueError):
                validate('SHOT.SE', data)

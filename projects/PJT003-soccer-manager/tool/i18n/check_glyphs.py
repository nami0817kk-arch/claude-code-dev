# -*- coding: utf-8 -*-
"""Report characters used in the UI that the bundled fonts cannot draw.

The app ships its own fonts so that Flutter Web does not fetch anything from
fonts.gstatic.com at runtime. That makes the bundled cmap the whole world: a
character missing from it renders as a tofu box, and nothing warns you --
`flutter analyze` is happy and the widget tests pass.

This actually happened: the English strings used U+00B7 MIDDLE DOT as a
separator, which neither bundled font contains, so every one of them drew a
box. U+2022 BULLET is present and reads the same way.

Icon glyphs are not affected -- those come from IconData and their own font.
"""
import glob
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dartstr import scan_strings

FONTS = [
    'assets/fonts/NotoSansJP-Regular.ttf',
    'assets/fonts/NotoSansJP-Bold.ttf',
    'assets/fonts/ShipporiMincho-Regular.ttf',
    'assets/fonts/ShipporiMincho-SemiBold.ttf',
]


def coverage(path):
    """Return the set of code points the font's cmap maps (format 4 and 12)."""
    d = open(path, 'rb').read()
    num_tables = struct.unpack('>H', d[4:6])[0]
    cmap_off = None
    for i in range(num_tables):
        off = 12 + 16 * i
        if d[off:off + 4] == b'cmap':
            cmap_off = struct.unpack('>I', d[off + 8:off + 12])[0]
    if cmap_off is None:
        raise SystemExit(f'{path}: no cmap table')

    n = struct.unpack('>H', d[cmap_off + 2:cmap_off + 4])[0]
    subtable = None
    for i in range(n):
        rec = cmap_off + 4 + 8 * i
        pid, eid, off = struct.unpack('>HHI', d[rec:rec + 8])
        # 後に出てくる (3,10) の方が広いので、見つかるたびに上書きする。
        if (pid, eid) in ((3, 1), (3, 10), (0, 3), (0, 4)):
            subtable = cmap_off + off
    if subtable is None:
        raise SystemExit(f'{path}: no unicode cmap subtable')

    fmt = struct.unpack('>H', d[subtable:subtable + 2])[0]
    covered = set()
    if fmt == 4:
        seg_x2 = struct.unpack('>H', d[subtable + 6:subtable + 8])[0]
        seg = seg_x2 // 2
        ends = [struct.unpack('>H', d[subtable + 14 + 2 * i:subtable + 16 + 2 * i])[0]
                for i in range(seg)]
        sb = subtable + 16 + seg_x2
        starts = [struct.unpack('>H', d[sb + 2 * i:sb + 2 + 2 * i])[0]
                  for i in range(seg)]
        for s, e in zip(starts, ends):
            covered.update(range(s, min(e, 0xFFFF) + 1))
    elif fmt == 12:
        ngroups = struct.unpack('>I', d[subtable + 12:subtable + 16])[0]
        for i in range(ngroups):
            g = subtable + 16 + 12 * i
            s, e, _ = struct.unpack('>III', d[g:g + 12])
            covered.update(range(s, e + 1))
    else:
        raise SystemExit(f'{path}: unsupported cmap format {fmt}')
    return covered


# 文字列リテラルに出てくるが画面には出ない制御文字・書式文字。
IGNORED = set('\n\r\t\\$')


def main():
    covered = set()
    for f in FONTS:
        covered |= coverage(f)

    bad = {}
    for path in sorted(glob.glob('lib/**/*.dart', recursive=True)):
        src = open(path, encoding='utf-8').read()
        for start, end, quote, raw, body in scan_strings(src):
            for ch in body:
                cp = ord(ch)
                if ch in IGNORED or cp < 0x20 or cp in covered:
                    continue
                line = src[:start].count('\n') + 1
                bad.setdefault((cp, ch), []).append(f'{path}:{line}')

    for (cp, ch), where in sorted(bad.items()):
        print(f'U+{cp:04X} {ch!r} used in {len(where)} place(s): '
              f'{", ".join(where[:4])}')
    print('-----', len(bad), 'characters missing from the bundled fonts')
    return 1 if bad else 0


if __name__ == '__main__':
    raise SystemExit(main())

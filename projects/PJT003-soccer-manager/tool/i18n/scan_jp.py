# -*- coding: utf-8 -*-
"""Report Japanese string literals that are NOT yet behind a translation.

Uses the same Dart scanner as the applier. A regex cannot tokenize these files:
literals whose `${...}` interpolation contains its own quotes get cut in half,
which produced dozens of phantom "untranslated" entries.

Literals already inside a Tr.pick(...) call or a (ja:, en:) record are skipped,
as are comments -- those are for whoever reads the code, not the player.
"""
import re, sys, glob, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dartstr import scan_strings, protected_spans, JP


# このマーカーを含むリテラルは、UIの文言ではなく意図した日本語データとして
# 見逃す。ファイル全体ではなく宣言単位で外せるよう、直前の行に書く運用。
OPT_OUT = 'i18n-ignore'


def scan(path):
    src = open(path, encoding='utf-8').read()
    prot = protected_spans(src)
    out = []
    for start, end, quote, raw, body in scan_strings(src):
        if any(a <= start and end <= b for a, b in prot):
            continue
        # 直前の20行以内に i18n-ignore があれば、意図した日本語データとみなす。
        head = src.rfind('\n', 0, start)
        window = src[max(0, head - 1200):start]
        if OPT_OUT in window.rsplit(';', 1)[-1] or OPT_OUT in window[-400:]:
            continue
        # 補間の中に Tr.pick が入っていることがある(例: 負傷歴の一覧)。
        # その部分は訳し終わっているので、日本語判定から外す。
        masked = body
        for a, b in prot:
            if start < a and b < end:
                masked = masked.replace(src[a:b], '')
        if not JP.search(masked):
            continue
        out.append(body)
    return out


if __name__ == '__main__':
    roots = sys.argv[1:] or ['lib']
    files = []
    for r in roots:
        if r.endswith('.dart'):
            files.append(r)
        else:
            files += glob.glob(os.path.join(r, '**', '*.dart'), recursive=True)
    total, rows = 0, []
    for f in sorted(set(files)):
        # 生成物。ARB(日本語)が原本なので日本語が入っていて当然。
        if re.search(r'l10n/app_localizations.*\.dart$', f):
            continue
        hits = scan(f)
        if hits:
            rows.append((len(hits), f))
            total += len(hits)
    for n, f in sorted(rows, reverse=True):
        print('%5d  %s' % (n, f))
    print('----- %d untranslated literals in %d files' % (total, len(rows)))

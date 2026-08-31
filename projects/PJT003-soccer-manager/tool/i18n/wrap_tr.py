# -*- coding: utf-8 -*-
"""Wrap Japanese Dart string literals in Tr.pick(ja, en), using a real scanner.

Idempotent: literals already inside a Tr.pick(...) call or a (ja:, en:) record
are left alone, so a file can be re-run safely.
"""
import re, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dartstr import scan_strings, protected_spans, JP



def lit(s):
    """Render a Dart literal, picking quotes so nothing needs escaping."""
    if "'" in s and '"' not in s:
        return '"%s"' % s
    if "'" in s:
        return "'%s'" % s.replace("'", r"\'")
    return "'%s'" % s


def apply(path, mapping, import_path):
    src = open(path, encoding='utf-8').read()
    prot = protected_spans(src)

    def inside(a, b):
        return any(p0 <= a and b <= p1 for p0, p1 in prot)

    edits, missing = [], []
    for start, end, quote, raw, body in scan_strings(src):
        if not JP.search(body) or raw or quote != "'" or inside(start, end):
            continue
        en = mapping.get(body)
        if en is None:
            missing.append(body)
            continue
        edits.append((start, end, 'Tr.pick(%s, %s)' % (src[start:end], lit(en))))

    for start, end, repl in reversed(edits):
        src = src[:start] + repl + src[end:]

    if edits and "import '%s';" % import_path not in src:
        imports = list(re.finditer(r"^import '[^']+';$", src, re.M))
        if imports:
            k = imports[-1].end()
            src = src[:k] + "\nimport '%s';" % import_path + src[k:]
        else:
            src = "import '%s';\n\n" % import_path + src

    open(path, 'w', encoding='utf-8').write(src)
    return len(edits), missing


if __name__ == '__main__':
    mod = __import__(sys.argv[1])
    total_missing = []
    for path in sys.argv[3:]:
        hits, missing = apply(path, mod.M, sys.argv[2])
        print('%-52s +%d' % (path, hits), end='')
        if missing:
            uniq = []
            for m in missing:
                if m not in uniq:
                    uniq.append(m)
            print('   MISSING %d' % len(uniq))
            total_missing += uniq
        else:
            print()
    if total_missing:
        print('\n--- untranslated (%d) ---' % len(total_missing))
        for m in total_missing:
            print(m)

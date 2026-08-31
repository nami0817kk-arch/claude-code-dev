# -*- coding: utf-8 -*-
"""A small scanner for Dart source that yields string-literal spans.

A regex is not enough here: this codebase has literals whose `${...}`
interpolation contains newlines, nested braces and nested string literals,
because dart format wraps long lines. Matching those with a regex silently
produces half-literals and corrupts the file. So we walk the source instead.
"""
import re

JP = re.compile(r'[぀-ゟ゠-ヿ一-鿿]')

# 全角の約物。かな/漢字ではないので JP には掛からないが、英語表示に
# 混ざると明確に不自然になる。翻訳済みの断片を全角括弧で連結している
# 箇所 (例: '${theme.label}（${theme.flavorLabel}）') を捕まえるために、
# 未翻訳判定ではこちらも日本語として扱う。
JP_PUNCT = re.compile(r'[（）、。・「」『』〜]')

# 未翻訳リテラルの判定に使う総合パターン。
JP_ANY = re.compile('|'.join(x.pattern for x in (JP, JP_PUNCT)))


def scan_strings(src):
    """Yield (start, end, quote, raw, body) for every top-level string literal.

    Strings nested inside an interpolation are not yielded separately; the
    outer literal's span covers them, which is what we want for wrapping.
    """
    i, n = 0, len(src)
    out = []
    while i < n:
        c = src[i]
        # line comment
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            j = src.find('\n', i)
            i = n if j < 0 else j + 1
            continue
        # block comment
        if c == '/' and i + 1 < n and src[i + 1] == '*':
            j = src.find('*/', i + 2)
            i = n if j < 0 else j + 2
            continue
        # string (optionally raw)
        raw = False
        start = i
        if c == 'r' and i + 1 < n and src[i + 1] in '\'"':
            raw = True
            i += 1
            c = src[i]
        if c in '\'"':
            triple = src[i:i + 3] in ("'''", '"""')
            quote = src[i:i + 3] if triple else c
            i += len(quote)
            body_start = i
            while i < n:
                if not raw and src[i] == '\\':
                    i += 2
                    continue
                if not raw and src[i] == '$' and i + 1 < n and src[i + 1] == '{':
                    i = _skip_interpolation(src, i + 1)
                    continue
                if src.startswith(quote, i):
                    break
                i += 1
            body = src[body_start:i]
            i += len(quote)
            out.append((start, i, quote, raw, body))
            continue
        i += 1
    return out


def _skip_interpolation(src, i):
    """i points at '{'. Return the index just past the matching '}'."""
    depth, n = 0, len(src)
    while i < n:
        c = src[i]
        if c in '\'"':
            # a nested string inside the interpolation
            triple = src[i:i + 3] in ("'''", '"""')
            q = src[i:i + 3] if triple else c
            i += len(q)
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if src[i] == '$' and i + 1 < n and src[i + 1] == '{':
                    i = _skip_interpolation(src, i + 1)
                    continue
                if src.startswith(q, i):
                    i += len(q)
                    break
                i += 1
            continue
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return i


def already_wrapped(src, start):
    """True if this literal is already an argument of Tr.pick( or a (ja:/en:) pair."""
    before = src[max(0, start - 40):start]
    return bool(re.search(r'(Tr\.pick\(\s*|,\s*|\(\s*ja:\s*|,\s*en:\s*)$', before)) and (
        'Tr.pick(' in src[max(0, start - 400):start].rsplit(';', 1)[-1]
        or '(ja:' in before or 'en:' in before)

def protected_spans(src):
    """Spans of existing Tr.pick(...) calls and (ja:..., en:...) records."""
    spans = []
    for m in re.finditer(r'Tr\.pick\(|\(\s*ja:', src):
        i = src.index('(', m.start())
        depth, j, n = 0, i, len(src)
        strs = None
        while j < n:
            c = src[j]
            if c in '\'"':
                if strs is None:
                    strs = {s[0]: s[1] for s in scan_strings(src)}
                if c and j in strs:
                    j = strs[j]
                    continue
            if c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
                if depth == 0:
                    j += 1
                    break
            j += 1
        spans.append((m.start(), j))
    return spans

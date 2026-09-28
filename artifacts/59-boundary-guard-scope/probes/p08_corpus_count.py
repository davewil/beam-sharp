#!/usr/bin/env python3
"""p08_corpus_count -- how many functions in the repo's own .bs corpus a scope change would touch.
LABEL: SOURCE-approximate: a regex over `git ls-files '*.bs'`, NOT bsc's parser. It counts signatures, not clauses,
and only params whose type token is a declared `record`, or `int` / `float` (refined-int aliases are NOT counted,
so the kind numbers are a lower bound).
PREDICTION (before running): private functions with a record parameter exist (F14's pipelines, F46's Shop.Pricing
helpers) but are a minority; private int helpers are far more common than private record helpers.
"""
import re, subprocess, collections
files = subprocess.check_output(['git', 'ls-files', '*.bs'], text=True).split()
src = {f: open(f).read() for f in files}
records = set()
for t in src.values():
    records.update(re.findall(r'^\s*(?:public\s+|private\s+)?record\s+(\w+)', t, re.M))
sig = re.compile(r'^(public\s+|private\s+)?([A-Za-z_][\w<>,\s\(\)\.\|:\[\]-]*?)\s+([A-Z]\w*)(?:<[^>]*>)?\(([^()]*(?:\([^()]*\)[^()]*)*)\)\s*$', re.M)
cnt = collections.Counter()
seen = 0
for f, t in src.items():
    for m in sig.finditer(t):
        vis, ret, name, params = m.groups()
        # a signature is followed by a clause line beginning with the same name
        rest = t[m.end():m.end()+400]
        if not re.match(r'\s*' + re.escape(name) + r'\b', rest):
            continue
        seen += 1
        pub = (vis or '').strip() == 'public'
        depth = 0; parts = []; cur = ''
        for ch in params:
            if ch in '(<': depth += 1
            if ch in ')>': depth -= 1
            if ch == ',' and depth == 0: parts.append(cur); cur = ''
            else: cur += ch
        if cur.strip(): parts.append(cur)
        toks = [p.strip().rsplit(' ', 1)[0].strip() for p in parts if p.strip()]
        has_rec = any(tk in records for tk in toks)
        has_int = any(tk == 'int' for tk in toks)
        has_flt = any(tk == 'float' for tk in toks)
        k = 'public' if pub else 'private'
        cnt[(k, 'all')] += 1
        cnt[(k, 'record param')] += has_rec
        cnt[(k, 'int param')] += has_int
        cnt[(k, 'float param')] += has_flt
print(f"{len(files)} .bs files, {len(records)} distinct record names, {seen} signatures matched")
print(f"{'':10}{'functions':>10}{'>=1 record param':>18}{'>=1 int param':>15}{'>=1 float param':>17}")
for k in ('public', 'private'):
    print(f"{k:10}{cnt[(k,'all')]:>10}{cnt[(k,'record param')]:>18}{cnt[(k,'int param')]:>15}{cnt[(k,'float param')]:>17}")

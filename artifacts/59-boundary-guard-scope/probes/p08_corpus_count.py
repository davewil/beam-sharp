#!/usr/bin/env python3
"""p08_corpus_count -- how many functions in the repo's own .bs corpus a scope change would touch.
LABEL: SOURCE-approximate: a line-based scan over `git ls-files '*.bs'`, NOT bsc's parser. It counts signatures, not
clauses, and only params whose type token is a declared `record`, or `int` / `float` (refined-int aliases are NOT
counted, so the kind numbers are a lower bound). The record-name set is global across files, so a same-named
non-record type would inflate it slightly.

HISTORY (disclosed): version 1 was a multi-line regex. An independent verifier found it (a) required the return type to
start [A-Za-z_], so `public :ok | :error Pick(int n)` and `public (:ok, int) Init(int seed)` read `public` as the return
type and counted as private, and (b) let the return type span a newline, so `module M\\npublic int F(..)` matched as a
private function. Version 2 (this file) reads visibility from the first word of the signature LINE. A signature line is
a line that starts in column 0, ends in `Name(params)`, contains no `->`, and whose next non-blank line starts with
`Name(`. A signature with no `public`/`private` word is private (F12: private is the default).

PREDICTION (before running, version 1): private functions with a record parameter exist but are a minority; private int
helpers are more common than private record helpers.
"""
import re, subprocess, collections
files = subprocess.check_output(['git', 'ls-files', '*.bs'], text=True).split()
src = {f: open(f).read().split('\n') for f in files}
records = set()
for L in src.values():
    for l in L:
        records.update(re.findall(r'^\s*(?:public\s+|private\s+)?record\s+(\w+)', l))
KEYWORDS = ('module', 'record', 'type', 'using', 'import', 'implements', 'behaviour', 'foreign', '//', 'public record', 'public type')
sigline = re.compile(r'^(public\s+|private\s+)?(\S.*?)\s*\b([A-Z]\w*)(?:<[^>]*>)?\(((?:[^()]|\([^()]*\))*)\)\s*$')
cnt = collections.Counter()
sample = []
for f, L in src.items():
    for i, l in enumerate(L):
        if not l or l[0] in ' \t}/' or '->' in l: continue
        m = sigline.match(l)
        if not m: continue
        vis, ret, name, params = m.groups()
        if not vis and re.match(r'(module|record|type|using|import|implements|behaviour|foreign)\b', l): continue
        j = i + 1
        while j < len(L) and not L[j].strip(): j += 1
        if j >= len(L) or not re.match(r'\s*' + re.escape(name) + r'\b', L[j]): continue
        pub = (vis or '').strip() == 'public'
        depth = 0; parts = []; cur = ''
        for ch in params:
            if ch in '(<': depth += 1
            if ch in ')>': depth -= 1
            if ch == ',' and depth == 0: parts.append(cur); cur = ''
            else: cur += ch
        if cur.strip(): parts.append(cur)
        toks = [p.strip().rsplit(' ', 1)[0].strip() if ' ' in p.strip() else p.strip() for p in parts if p.strip()]
        k = 'public' if pub else 'private'
        cnt[(k, 'all')] += 1
        cnt[(k, 'record param')] += any(tk in records for tk in toks)
        cnt[(k, 'int param')] += any(tk == 'int' for tk in toks)
        cnt[(k, 'float param')] += any(tk == 'float' for tk in toks)
        if len(sample) < 10 and (i % 7 == 0): sample.append((k, f, l))
print(f"{len(files)} .bs files, {len(records)} distinct record names")
print(f"{'':10}{'functions':>10}{'>=1 record param':>18}{'>=1 int param':>15}{'>=1 float param':>17}")
for k in ('public', 'private'):
    print(f"{k:10}{cnt[(k,'all')]:>10}{cnt[(k,'record param')]:>18}{cnt[(k,'int param')]:>15}{cnt[(k,'float param')]:>17}")
print("\nsample of classified signature lines (for hand-checking):")
for k, f, l in sample: print(f"  {k:8} {f[-38:]:38} | {l[:60]}")

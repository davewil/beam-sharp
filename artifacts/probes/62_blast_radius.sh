#!/usr/bin/env bash
# PROBE 62_blast_radius (ticket 62, option 3: "change B#'s own convention")
# CLAIM: option 3 has the largest blast radius. This counts what it would touch:
# public function DECLARATIONS (a `public <type> Name(...)` signature line, which
# is what a foreign caller sees as an export), and every uppercase-initial
# clause head, per tree. Calls are NOT counted (not measured).
# REFUTES "largest blast radius" if the counts are small relative to the alias
# option's cost; the counts are printed, the reader judges. Control: the same
# regexes on a tree with a known count (a 3-function fixture) must print 3/3.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
python3 -I - "$REPO" "$(dirname "${BASH_SOURCE[0]}")" <<'PY'
import re, sys, os, glob
repo, here = sys.argv[1], sys.argv[2]
SIG  = re.compile(r'^(public\s+)?[^\s/][^()]*?\s([A-Z]\w*)\(([^()]*(\([^()]*\))?[^()]*)\)\s*\{?\s*$')
HEAD = re.compile(r'^([A-Z]\w*)\(.*->')
def scan(lines):
    pub = priv = heads = 0; names = set()
    for l in lines:
        l = l.rstrip('\n')
        if '->' not in l:
            m = SIG.match(l)
            if m and not l.startswith(('//', ' ', '\t', 'using', 'record', 'type', 'module', 'protocol', 'foreign')):
                if m.group(1): pub += 1; names.add(m.group(2))
                else: priv += 1
        if HEAD.match(l): heads += 1
    return pub, priv, heads, names
def tree(root, pat='**/*.bs', skip=()):
    t = [0,0,0]; files = 0; names=set()
    for f in glob.glob(os.path.join(root, pat), recursive=True):
        if any(s in f for s in skip): continue
        files += 1
        p, q, h, n = scan(open(f, encoding='utf-8'))
        t[0]+=p; t[1]+=q; t[2]+=h; names|=n
    return files, t, names
def md(path):
    inside=False; buf=[]
    for l in open(path, encoding='utf-8'):
        if l.startswith('```'): inside = not inside; continue
        if inside: buf.append(l)
    return scan(buf)
fx = os.path.join(here, '62_fixtures', 'Awk')
print('control: Awk fixture (7 public fns, 7 clause heads) ->', tree(fx)[:2])
print('%-34s %5s %7s %8s %12s' % ('tree', 'files', 'public', 'private', 'clause heads'))
for label, root, skip in [('compiler/examples', 'compiler/examples', ()),
                          ('aoc', 'aoc', ()),
                          ('handoff', 'handoff', ()),
                          ('wayfinder/prototypes', 'wayfinder/prototypes', ())]:
    n, t, _ = tree(os.path.join(repo, root), skip=skip)
    print('%-34s %5d %7d %8d %12d' % (label + '/*.bs', n, t[0], t[1], t[2]))
for f in ['LANGUAGE.md', 'TOUR.md']:
    p, q, h, _ = md(os.path.join(repo, f))
    print('%-34s %5s %7d %8d %12d   (fenced blocks only)' % (f, '-', p, q, h))
PY
rm -f "$(dirname "${BASH_SOURCE[0]}")/62_blast_radius.py"

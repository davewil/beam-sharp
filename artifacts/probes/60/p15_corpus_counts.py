#!/usr/bin/env python3
# MEASUREMENT: can a subtree rule be decided from the directory path alone, and how many of the repo's own
# modules/edges would it touch? Module path = directory relative to the corpus root (F15, enforced by
# module_path_mismatch). A directory holding .bs files is a module; a directory holding only directories is a
# namespace (41 section 5, F15.8, F15.11).
# REFUTED (that the path alone decides it) IF any directory's declared `module` differs from its path-derived name.
import os, re, sys, collections
here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.abspath(os.path.join(here, '..', '..', '..'))
root = os.path.join(repo, 'compiler', 'examples')
mods = {}   # path-derived name -> declared name(s)
uses = collections.defaultdict(list)
for d, dirs, files in os.walk(root):
    if os.path.relpath(d, root).split(os.sep)[0] == 'exemplars': dirs[:] = []; continue
    bs = [f for f in files if f.endswith('.bs')]
    if not bs: continue
    name = '.'.join(os.path.relpath(d, root).split(os.sep))
    for f in bs:
        txt = open(os.path.join(d, f)).read()
        m = re.search(r'^module\s+([A-Za-z0-9_.]+)', txt, re.M)
        decl = m.group(1) if m else None
        mods.setdefault(name, set()).add(decl)
        for u in re.findall(r'^using\s+([A-Z][A-Za-z0-9_.]*)\s*$', txt, re.M):
            uses[name].append(u)
bad = {n: d for n, d in mods.items() if d - {None, n}}
print(f'modules (directories holding .bs, exemplars excluded): {len(mods)}')
print(f'  path-derived name != declared module name: {len(bad)}  {bad if bad else ""}')
print(f'  files with no `module` line (inherit): {sum(1 for d in mods.values() if None in d)} dirs')
dotted = [n for n in mods if '.' in n]
print(f'  modules with a dotted path (have a parent namespace/module): {len(dotted)} -> {sorted(dotted)}')
print(f'  single-segment modules (no parent; a subtree rule has nothing to scope): {len(mods)-len(dotted)}')
def known(u): return u in mods
def children(u): return [m for m in mods if m.startswith(u + '.')]
edges = []
for s, us in uses.items():
    for u in us:
        kind = 'module' if known(u) else ('namespace' if children(u) else 'unknown')
        edges.append((s, u, kind))
print(f'cross-module `using` edges (B# modules only; `using :erlang {{..}}` is foreign and excluded): {len(edges)}')
for s, u, k in edges:
    # the subtree-from-parent rule (candidate A/C scope): does Self sit under the TARGET's parent namespace?
    t = u if k == 'namespace' else u
    par = t.rsplit('.', 1)[0] if '.' in t else t
    under = s == par or s.startswith(par + '.')
    print(f'    {s:16s} -> {u:24s} [{k}]  target parent scope "{par}"  caller under it: {under}')
n_out = sum(1 for s,u,k in edges if not (s == (u.rsplit('.',1)[0] if '.' in u else u) or s.startswith((u.rsplit('.',1)[0] if '.' in u else u) + '.')))
print(f'edges that WOULD be refused if every module were scoped to its parent namespace: {n_out} of {len(edges)}')
print(f'modules that are the target of at least one edge: {len({u for _,u,_ in edges})}')
# exemplars: parse-free text scan, because none of them parse yet (examples/exemplars/README.md)
ex = os.path.join(root, 'exemplars'); tot = 0; native = []
for d, _, files in os.walk(ex):
    for f in files:
        if f.endswith('.bs'):
            for u in re.findall(r'^using\s+([A-Z][A-Za-z0-9_.]*)\s*$', open(os.path.join(d, f)).read(), re.M):
                native.append((os.path.relpath(d, ex), u))
print(f'exemplars (do not all parse; text scan): native `using` lines: {native}')
sys.exit(1 if bad else 0)

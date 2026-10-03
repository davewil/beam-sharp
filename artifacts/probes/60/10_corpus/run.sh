#!/bin/sh
# Probe 60/10: is there demand in the corpus? How many modules are named (`using`) by another module at all?
cd /home/user/beam-sharp
echo "commit: $(git rev-parse --short HEAD)"
echo ".bs files outside artifacts/ and _build/: $(find . -name '*.bs' -not -path './artifacts/*' -not -path '*/_build/*' | wc -l)"
python3 - <<'PY'
import re, os, collections
mods = collections.defaultdict(set); uses = collections.defaultdict(set); pub = collections.defaultdict(int)
for root, _, fs in os.walk('.'):
    if 'artifacts' in root or '_build' in root or '.git' in root: continue
    for f in fs:
        if not f.endswith('.bs'): continue
        t = open(os.path.join(root, f), errors='ignore').read()
        m = re.search(r'^module\s+([\w.]+)', t, re.M)
        if not m: continue
        M = m.group(1); mods[M].add(root)
        for u in re.findall(r'^\s*using\s+([\w.]+)', t, re.M): uses[M].add(u)
        pub[M] += len(re.findall(r'^public\s', t, re.M))
imp = collections.defaultdict(set)
for M, us in uses.items():
    for u in us: imp[u].add(M)
print('distinct module names:', len(mods))
print('`using` lines name (module or namespace):', sum(len(v) for v in uses.values()), 'edges across', len(uses), 'importing modules')
named = [M for M in mods if imp[M]]
print('modules named by at least one other module:', len(named))
for M in sorted(named): print('  %-24s public fns=%d  named by %s' % (M, pub[M], sorted(imp[M])))
print('namespace-only `using` targets (not a module):', sorted(u for u in imp if u not in mods))
PY

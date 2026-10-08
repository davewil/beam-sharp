# P10: how much demand does the real corpus show? For every B# module in the repo, who `using`s it, and would the importers all sit inside a
# candidate "private to a subtree" unit? Pure text scan of `module` / `using` lines (// comments stripped); no compiler involved.
import os, re, sys, collections
root = sys.argv[1] if len(sys.argv) > 1 else '.'
mods = {}          # module -> set(files)
uses = collections.defaultdict(set)   # module -> set(modules it `using`s)
for d, _, fs in os.walk(root):
    if '/.git' in d or 'node_modules' in d: continue
    for f in fs:
        if not f.endswith('.bs'): continue
        p = os.path.join(d, f); m = None; us = []
        for line in open(p, encoding='utf-8', errors='replace'):
            line = line.split('//')[0].strip()
            mm = re.match(r'module\s+([A-Za-z0-9_.]+)', line)
            if mm: m = mm.group(1)
            uu = re.match(r'using\s+([A-Z][A-Za-z0-9_.]*)\s*$', line)
            if uu: us.append(uu.group(1))
        if m:
            mods.setdefault(m, set()).add(p); uses[m].update(us)
known = set(mods)
importers = collections.defaultdict(set)
for m, us in uses.items():
    for u in us:
        if u in known and u != m: importers[u].add(m)
def under(a, b): return a == b or a.startswith(b + '.')
n = len(known); multi = [m for m in known if '.' in m]
print(f"modules: {n}; dotted (namespaced): {len(multi)}; modules named by >=1 other module: {sum(1 for m in known if importers[m])}")
print(f"cross-module `using` edges between known modules: {sum(len(v) for v in importers.values())}")
# unit candidates: (a) the callee's own subtree  (b) the callee's parent namespace subtree
def cls(m, unit):
    imp = importers[m]
    if not imp: return None
    return all(under(i, unit) for i in imp)
for name, unit_of in (("callee's own subtree", lambda m: m), ("callee's parent namespace", lambda m: m.rsplit('.', 1)[0] if '.' in m else None)):
    cand = [m for m in known if importers[m] and unit_of(m) and cls(m, unit_of(m))]
    print(f"importers ALL inside {name}: {len(cand)} of {sum(1 for m in known if importers[m])} imported modules")
    for m in sorted(cand)[:8]: print("    ", m, "<-", sorted(importers[m]))
print("modules with a path segment 'Internal':", [m for m in known if 'Internal' in m.split('.')])

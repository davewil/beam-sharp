#!/usr/bin/env python3
"""P8: demand census. Over every .bs under compiler/examples (shipped programs and exemplars),
per module: public functions, and how many are named from a DIFFERENT module that `using`s it.
Crude by design (token match on the function name in importing files); it bounds the demand
for 'who may name this', it does not prove it."""
import re, sys, os, subprocess, collections
root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
files = subprocess.check_output(["git","ls-files","compiler/examples","aoc","handoff"], cwd=root, text=True).split()
files = [f for f in files if f.endswith(".bs")]
mods = collections.defaultdict(lambda: {"files": [], "pub": set(), "priv": set(), "using": set(), "dir": None})
for f in files:
    src = open(os.path.join(root, f)).read()
    m = re.search(r'^module\s+([A-Za-z0-9_.]+)', src, re.M)
    name = m.group(1) if m else "<no module line>:" + os.path.dirname(f)
    e = mods[name]; e["files"].append(f)
    for v, fn in re.findall(r'^(public|private)\s+[^\n]*?\b([A-Z][A-Za-z0-9_]*)\s*(?:<[^>]*>)?\(', src, re.M):
        (e["pub"] if v == "public" else e["priv"]).add(fn)
    for u in re.findall(r'^using\s+([A-Z][A-Za-z0-9_.]*)\s*$', src, re.M): e["using"].add(u)
edges = sum(len(e["using"] & set(mods)) for e in mods.values())
print(f"bs files: {len(files)}   modules: {len(mods)}   using-edges between modules in corpus: {edges}")
names_in = {n: " ".join(open(os.path.join(root, f)).read() for f in e["files"]) for n, e in mods.items()}
pub_total = exported_used = 0; unused = []
for n, e in mods.items():
    importers = [i for i, ie in mods.items() if i != n and n in ie["using"]]
    for fn in sorted(e["pub"]):
        pub_total += 1
        if any(re.search(r'\b' + fn + r'\b', names_in[i]) for i in importers): exported_used += 1
        else: unused.append((n, fn))
print(f"public functions: {pub_total}   named from another corpus module: {exported_used}   named by none: {len(unused)}")
# the shape the ticket is about: a module that is `using`'d only by modules sharing its first path segment
shared = []
for n, e in mods.items():
    imps = [i for i, ie in mods.items() if i != n and n in ie["using"]]
    if imps: shared.append((n, imps))
for n, imps in sorted(shared): print(f"  {n}  <- {', '.join(sorted(imps))}")
print(f"modules named by at least one other module: {len(shared)}")

# P5: in the repo's own .bs corpus, which modules does each module `using`, and how many distinct
# caller modules does each callee have? (module-tier `using Uident.Path` lines only; foreign
# `using :atom {` blocks are counted separately). Module of a directory = the `module X` declared
# in any of its files, else the directory path relative to the root.
import os, re, sys, collections
root = sys.argv[1]
mod_of_dir = {}
for d, _, fs in os.walk(root):
    bs = [f for f in fs if f.endswith(".bs")]
    if not bs: continue
    decl = None
    for f in bs:
        m = re.search(r"^module\s+([A-Z][\w.]*)", open(os.path.join(d, f), encoding="utf8").read(), re.M)
        if m: decl = m.group(1); break
    mod_of_dir[d] = decl or os.path.relpath(d, root).replace(os.sep, ".")
callers = collections.defaultdict(set); foreign = 0; files = 0
for d, mod in mod_of_dir.items():
    for f in os.listdir(d):
        if not f.endswith(".bs"): continue
        files += 1
        for ln in open(os.path.join(d, f), encoding="utf8"):
            m = re.match(r"using\s+([A-Z][\w.]*)\s*$", ln)
            if m and m.group(1) != mod: callers[m.group(1)].add(mod)
            elif re.match(r"using\s+:", ln): foreign += 1
mods = set(mod_of_dir.values())
named = {c: sorted(s) for c, s in callers.items() if c in mods}
print(f"root={root} bs_files={files} modules={len(mods)} foreign_using={foreign}")
print(f"modules named by at least one other module: {len(named)}")
hist = collections.Counter(len(v) for v in named.values())
print("distinct caller modules per callee (callers: count of callees):", dict(sorted(hist.items())))
for c, v in sorted(named.items()): print(f"  {c} <- {', '.join(v)}")

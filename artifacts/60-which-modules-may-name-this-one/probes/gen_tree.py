#!/usr/bin/env python3
"""Generate a synthetic B# tree: N modules M0..M{N-1} under Gen/, module i has K `using` edges to earlier modules
and calls one public function from each. WITHIN=1 adds `within Gen` to every module."""
import sys, os, random
n, k, within, out = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
random.seed(7)
for i in range(n):
    d = f"{out}/Gen/M{i}"; os.makedirs(d, exist_ok=True)
    deps = sorted(random.sample(range(i), min(k, i))) if i else []
    s = f"module Gen.M{i}\n\n" + (("within Gen\n\n") if within else "")
    s += "".join(f"using Gen.M{j}\n" for j in deps) + "\n"
    s += f"public int F{i}(int x)\n"
    s += f"F{i}(x) -> x + 1" + "".join(f" + F{j}(x)" for j in deps[:3]) + "\n"
    open(f"{d}/F{i}.bs", "w").write(s)

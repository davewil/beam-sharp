#!/usr/bin/env python3
# usage: gen_modules.py OUTDIR  -> OUTDIR/N<n>/n<n>.bs for n in 1,10,100,1000 (module N<n>)
import os, sys
out = sys.argv[1]
for n in (1, 10, 100, 1000):
    d = os.path.join(out, "N%d" % n); os.makedirs(d, exist_ok=True)
    lines = ["module N%d\n" % n]
    for i in range(n):
        nm = "GetItem%d" % i
        lines.append("public int %s(int x)\n%s(0) -> 0\n%s(x) -> x + %d\n" % (nm, nm, nm, i))
    open(os.path.join(d, "n%d.bs" % n), "w").write("\n".join(lines))

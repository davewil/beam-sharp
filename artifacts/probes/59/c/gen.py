#!/usr/bin/env python3
# usage: gen.py DIR N  -- writes DIR/CostRec/*.bs and DIR/CostInt/*.bs, each with N PRIVATE functions
import sys, os
d, n = sys.argv[1], int(sys.argv[2])
os.makedirs(f"{d}/CostRec", exist_ok=True); os.makedirs(f"{d}/CostInt", exist_ok=True)
r = ["module CostRec", "record Order { Id: int, Total: int }", "record Cart { Item: Order, N: int }", ""]
for k in range(n):
    r += [f"int P{k}(Order o)", f"P{k}(o) -> o.Total + {k}", ""]
r += ["public int Main(Cart c)", "Main(c) -> " + " + ".join(f"P{k}(c.Item)" for k in range(n)) if n else "Main(c) -> 0"]
open(f"{d}/CostRec/costrec.bs", "w").write("\n".join(r) + "\n")
i = ["module CostInt", "record Cart { N: int }", ""]
for k in range(n):
    i += [f"int Q{k}(int n)", f"Q{k}(n) -> n * {k + 2}", ""]
i += ["public int Main(Cart c)", "Main(c) -> " + " + ".join(f"Q{k}(c.N)" for k in range(n)) if n else "Main(c) -> 0"]
open(f"{d}/CostInt/costint.bs", "w").write("\n".join(i) + "\n")

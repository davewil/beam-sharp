#!/usr/bin/env python3
"""exemplar_census.py ROOT : SOURCE-LEVEL count (the exemplars do not compile yet) of private signatures
whose parameters would receive a boundary test under the scope options.  A parameter is
  rec   : its declared type is a `record X` declared in the same exemplar directory (single closed record
          => tag test; a union of records gets none)
  int   : exactly `int`        flt : exactly `float`
Prints per-exemplar and total.  Heuristic (regex, top-level comma split); it is NOT the compiler."""
import re, sys, os, collections
root = sys.argv[1]
tot = collections.Counter()
for d in sorted(os.listdir(root)):
    p = os.path.join(root, d)
    if not os.path.isdir(p): continue
    src = ""
    for f in sorted(os.listdir(p)):
        if f.endswith(".bs"): src += open(os.path.join(p, f)).read() + "\n"
    records = set(re.findall(r"^record\s+(\w+)", src, re.M))
    unions  = set(re.findall(r"^type\s+(\w+)\s*=\s*(\w+(?:\s*\|\s*\w+)+)\s*$", src, re.M) and
                  [m[0] for m in re.findall(r"^type\s+(\w+)\s*=\s*(\w+(?:\s*\|\s*\w+)+)\s*$", src, re.M)])
    c = collections.Counter()
    for vis, ret, name, params in re.findall(r"^(private|public)\s+(.+?)\s+(\w+)\((.*)\)\s*$", src, re.M):
        if vis != "private": c["pub_fns"] += 1; continue
        c["priv_fns"] += 1
        depth, cur, parts = 0, "", []
        for ch in params:
            if ch in "<([{": depth += 1
            if ch in ">)]}": depth -= 1
            if ch == "," and depth == 0: parts.append(cur); cur = ""
            else: cur += ch
        if cur.strip(): parts.append(cur)
        kinds = set()
        for q in parts:
            ty = q.strip().rsplit(" ", 1)[0].strip() if " " in q.strip() else q.strip()
            if ty in records: kinds.add("rec")
            elif ty == "int": kinds.add("int")
            elif ty == "float": kinds.add("flt")
        for k in kinds: c["priv_with_" + k] += 1
        if kinds: c["priv_with_any"] += 1
    print(f"{d:32s} " + " ".join(f"{k}={c[k]}" for k in ["pub_fns","priv_fns","priv_with_rec","priv_with_int","priv_with_flt","priv_with_any"]))
    tot.update(c)
print(f"{'TOTAL':32s} " + " ".join(f"{k}={tot[k]}" for k in ["pub_fns","priv_fns","priv_with_rec","priv_with_int","priv_with_flt","priv_with_any"]))

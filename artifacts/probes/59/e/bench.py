#!/usr/bin/env python3
# Interleaved A/B/A' harness: each sample is a fresh VM (pinned to one core), variants rotated every round
# so drift hits all variants equally. base2 is a byte-identical copy of base: base-vs-base2 is the A/A noise floor.
import subprocess, statistics as st, sys, os
R = int(os.environ.get("ROUNDS", "15")); N = os.environ.get("ITERS", "50000000")
env = dict(os.environ, PATH="/tmp/otp/bin:" + os.environ["PATH"], LC_ALL="C.UTF-8")
plans = {"LoopRec": ["base", "proto", "base2"], "LoopInt": ["base", "wide", "base2"], "LoopCtl": ["base", "proto", "base2"], "LoopStruct": ["base", "base2"]}
def run(variant, fun):
    out = subprocess.run(["taskset", "-c", "2", "./bench.escript", f"out-{variant}", fun, N],
                         capture_output=True, text=True, env=env, check=True).stdout
    return float(out)
def q(xs, p):
    xs = sorted(xs); k = (len(xs) - 1) * p; f = int(k); c = min(f + 1, len(xs) - 1)
    return xs[f] + (xs[c] - xs[f]) * (k - f)
res = {}
for fun, vs in plans.items():
    s = {v: [] for v in vs}
    for r in range(R):
        order = vs[r % len(vs):] + vs[:r % len(vs)]
        for v in order: s[v].append(run(v, fun))
    res[fun] = s
for fun, s in res.items():
    print(f"\n== {fun}  ({R} VM runs per variant, {N} iterations each, ns per loop iteration)")
    print(f"{'variant':8} {'min':>8} {'median':>8} {'IQR':>7} {'max':>8}")
    for v, xs in s.items():
        print(f"{v:8} {min(xs):8.3f} {st.median(xs):8.3f} {q(xs,.75)-q(xs,.25):7.3f} {max(xs):8.3f}")
    b = s["base"]; b2 = s["base2"]
    aa = st.median(b) - st.median(b2)
    print(f"A/A  (base - base2)  median diff = {aa:+.3f} ns   <- noise floor of this method")
    if fun == "LoopStruct":
        d = st.median(res["LoopRec"]["base"]) - st.median(b)
        print(f"SAME-MODULE A/B  (LoopRec - LoopStruct, both from base build) median diff = {d:+.3f} ns")
    for v in s:
        if v in ("base", "base2"): continue
        d = st.median(s[v]) - st.median(b)
        dmin = min(s[v]) - min(b)
        print(f"A/B  ({v} - base)   median diff = {d:+.3f} ns   min diff = {dmin:+.3f} ns")

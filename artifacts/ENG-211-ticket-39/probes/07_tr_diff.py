# Compare the type annotations ({tr,..} operands and var_info) the optimizer left in Erlang's bench_erl vs the
# emitted-by-bsc Day01, function by function. Hypothesis H7 (the ticket's observation): beam-sharp's Spin has
# bare {x,0} where Erlang's has {tr,{x,0},..}. Falsified if the per-function annotation multisets are equal.
# Usage: python3 -I 07_tr_diff.py bench_erl.S Day01.S      (inputs are `erlc -S` / `erlc +from_abstr -S` output)
import re, sys, collections
PAIRS = [("wrap","'Wrap'"),("hit","'Hit'"),("spin","'Spin'"),("sign","'Sign'"),("size_","'Size'"),("clicks","'Clicks'")]
def sections(path):
    out, cur = {}, None
    for line in open(path):
        m = re.match(r"\{function, (\S+), (\d+),", line)
        if m: cur = m.group(1); out[cur] = []; continue
        if cur: out[cur].append(line)
    return out
def ann(lines):
    txt = " ".join(l.strip() for l in lines)
    txt = re.sub(r"\s+", " ", txt)
    c = collections.Counter(re.findall(r"\{tr,\{[xy],\d+\},\{[^}]*\}\}|\{tr,\{[xy],\d+\},\w+\}", txt))
    c.update(re.findall(r"\{type,\{t_integer,[^}]*\}\}\}?", txt))
    return c
a, b = sections(sys.argv[1]), sections(sys.argv[2])
bad = 0
for ea, bs in PAIRS:
    ca, cb = ann(a[ea]), ann(b[bs])
    same = ca == cb
    bad += not same
    print(f"{ea:7s} vs {bs:8s} erl={sum(ca.values()):2d} bs={sum(cb.values()):2d} {'SAME' if same else 'DIFFERENT'}")
    if not same:
        print("   only in erlang:", dict(ca - cb)); print("   only in bsc   :", dict(cb - ca))
print("RESULT:", "annotation gap reproduced" if bad else "no annotation difference on this OTP", f"(otp {sys.argv[3] if len(sys.argv)>3 else '?'})")

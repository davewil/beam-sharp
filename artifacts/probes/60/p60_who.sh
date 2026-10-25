#!/usr/bin/env bash
# Ticket 60. Who may name this module?  Part 1 runs against the REAL compiler (no `internal` exists): can any module reach a
# helper, by `using` and by a qualified name with no `using` at all?  Part 2 runs the same tree against the prototype
# (P: an `internal` marker visible only inside the subtree rooted at the declarer's parent namespace).
. "$(dirname "$0")/../env.sh"
W=$(mktemp -d); S=$W/src; mkdir -p $S/Shop/Pricing $S/Shop/Reports $S/Other
KW=${KW:-public}   # visibility word written on RecomputeTotal
cat > $S/Shop/Pricing/p.bs <<X
module Shop.Pricing

public int Total(int n)
Total(n) -> Recompute(n) + 1

$KW int Recompute(int n)
Recompute(n) -> n * 2
X
cat > $S/Shop/Reports/r.bs <<'X'
module Shop.Reports

using Shop.Pricing

public int Report(int n)
Report(n) -> Recompute(n)
X
cat > $S/Other/o_using.bs <<'X'
module Other

using Shop.Pricing

public int Peek(int n)
Peek(n) -> Recompute(n)
X
mkdir -p $S/Other2; cat > $S/Other2/o_qual.bs <<'X'
module Other2

public int PeekQ(int n)
PeekQ(n) -> Shop.Pricing.Recompute(n)
X
mkdir -p $S/Other3; cat > $S/Other3/o_both.bs <<'X'
module Other3

using Shop.Pricing

public int PeekB(int n)
PeekB(n) -> Shop.Pricing.Recompute(n)
X
for m in Shop.Reports:Shop/Reports Other:Other Other2:Other2 Other3:Other3; do
  name=${m%%:*}; dir=${m##*:}
  out=$(bsc --src-root $S -o $W/out-$name $S/$dir 2>&1); rc=$?
  printf '%-14s rc=%s %s\n' "$name" $rc "$(echo "$out" | head -3 | tr '\n' ' ' | sed "s|$S/||g" | cut -c1-200)"
done

#!/usr/bin/env bash
# Differentiator: once Delta is writable, can a negative LITERAL be returned as a Delta?
# (Positive literals are singleton ranges today; `-3` is typed `int` because it is an e_neg node.)
HERE="$(cd "$(dirname "$0")" && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"; mkdir L
cat > L/l.bs <<'BS'
module L

type Delta = int where value >= -100 and value <= 100
type Pos   = int where value >= 0 and value <= 100

public Pos P()
P() -> 3

public Delta D()
D() -> -3

public Delta E()
E() -> 0 - 3
BS
for t in A B; do echo "== variant $t:"; "$HERE/work/$t/_build/default/bin/bsc" L 2>&1 | head -12; done

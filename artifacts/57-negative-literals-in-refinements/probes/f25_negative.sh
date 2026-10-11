#!/usr/bin/env bash
# f25_negative.sh [EBIN] : F2.5 ("a guard refinement and a type refinement agree") re-run over a signed domain.
# Control first: the unsigned F2.5 case must give `0..128`'s complement on every build.
S=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad
EBIN=${1:-$S/bsc-ebin}; source $S/env.sh
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
run () { mkdir -p $W/src/$1 $W/out/$1; { echo "module $1"; cat; } > $W/src/$1/a.bs; (cd $W/out/$1 && erl -noshell -pa $EBIN -run bsc main $W/src/$1/a.bs -run init stop 2>&1 | sed "s#$W/src/##" | head -${2:-6}); }
echo "## control (unsigned, F2.5 as written): guard n > 128 over 0..255"
run Oct <<'X'
type Octet = int where value >= 0 and value <= 255
public atom K(Octet n)
K(n) when n > 128 -> :hi
X
echo "## signed: guard n > -3 over -10..10"
run Sgn <<'X'
type D = int where value >= -10 and value <= 10
public atom K(D n)
K(n) when n > -3 -> :hi
X
echo "## signed, both halves covered by guards (must be accepted)"
run Sgn2 <<'X'
type D = int where value >= -10 and value <= 10
public atom K(D n)
K(n) when n > -3 -> :hi
K(n) when n <= -3 -> :lo
X
echo "(empty above = accepted)"

#!/usr/bin/env bash
# Probe 64/13 - PROTOTYPE of the compiler delta that closes the instantiation hole found in probe 02.
# Copies compiler/ to a temp dir (the real tree is not touched), applies inst_collapse.patch (~25 lines in
# bs_check.erl call/6 + one forwarding clause in bs_diag.erl), rebuilds with rebar3 and re-runs the Gen module.
# NOT a feature: it has no test, no gate and no self-test (CLAUDE.md requires all three before landing).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; REPO="$(cd "$HERE/../../../.." && pwd)"
W=$(mktemp -d); trap 'rm -rf $W' EXIT
cp -r "$REPO/compiler" $W/compiler; rm -rf $W/compiler/_build/default/bin
( cd $W && patch -p1 < "$HERE/inst_collapse.patch" ) | sed 's/^/patch: /'
( cd $W/compiler && rebar3 escriptize 2>&1 | grep -i "error" )
PB=$W/compiler/_build/default/bin/bsc
mkdir -p $W/Gen; cat > $W/Gen/Gen.bs <<'B'
module Gen
public option<T> Head<T>(list<T> xs)
Head([])        -> :nothing
Head([x, ..r])  -> x

public option<int> AtInt(list<int> xs)
AtInt(xs) -> Head(xs)

public term AtTerm(list<term> xs)
AtTerm(xs) -> Head(xs)

public atom AtAtom(list<atom> xs)
AtAtom(xs) -> Head(xs)
B
echo "=== stock bsc (HEAD) on Gen ==="; "$REPO/compiler/_build/default/bin/bsc" -o $W/o1 $W/Gen 2>&1 | sed "s|$W/||"; echo "exit=${PIPESTATUS[0]}"
echo; echo "=== prototype bsc on Gen: AtInt accepted, AtTerm and AtAtom refused at the CALL line ==="
$PB -o $W/o2 $W/Gen 2>&1 | sed "s|$W/||"; echo "exit=${PIPESTATUS[0]}"

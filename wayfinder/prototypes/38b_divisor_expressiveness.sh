#!/usr/bin/env bash
# 38b — can beam-sharp SPELL a divisor that excludes zero? Measured, not argued.
#
#     wayfinder/prototypes/38b_divisor_expressiveness.sh
#
# Ticket 38 §2 claimed "nothing in the surface yet says `int` WITHOUT zero except
# a guard", and that option (b) was "close to unbuildable" until ticket 20's
# refinement spelling landed. Both were written 2026-08-15. F2 landed the day
# after. This probe re-runs the claims against the real compiler.
#
# It also isolates the confound that nearly became a false finding: the first two
# refusals both happened to contain a NEGATIVE literal, which looked like "the
# checker cannot do a disjoint union". It can. It cannot read `-5`.
#
# TRAP, unrelated but costly: do not run bare `erl` with cwd inside `compiler/`.
# Stray example artefacts (`C.beam`, `Json.beam`) sit there, and on a
# case-insensitive filesystem `C.beam` shadows stdlib's `c` module, so the VM
# dies during boot with `undef c:erlangrc`. Run from the repo root.
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
bsc="$root/compiler/_build/default/bin/bsc"
if [ ! -x "$bsc" ]; then
    (cd "$root/compiler" && rebar3 escriptize >/dev/null 2>&1)
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fails=0

# One directory is one module (F15), so each case gets its own.
probe () {
    local name=$1 expect=$2 src=$3 out got mark
    mkdir -p "$work/$name"
    printf 'module %s\n%s\n' "$name" "$src" > "$work/$name/a.bs"
    if out=$("$bsc" "$work/$name/a.bs" 2>&1) && [ -z "$out" ]; then
        got=accepted
    else
        got=refused
    fi
    if [ "$got" = "$expect" ]; then
        mark="ok "
    else
        mark="!! "
        fails=$((fails + 1))
    fi
    printf '%s %-34s %s (expected %s)\n' "$mark" "$name" "$got" "$expect"
}

echo "== Can a non-zero divisor be declared? =="
probe NotEqualZero accepted '
type Nz = int where value != 0
public int Id(Nz b)
Id(b) -> b'

echo "== ...and does it actually EXCLUDE zero, or is it a silent no-op? =="
probe ZeroRejected refused '
type Nz = int where value != 0
public int Id(Nz b)
public int Go()
Id(b) -> b
Go() -> Id(0)'

echo "== Is a DISJOINT refinement the problem? (no -- this is accepted) =="
probe DisjointOr accepted '
type T = int where value <= 3 or value >= 10
public int Id(T b)
Id(b) -> b'

echo "== It is the NEGATIVE LITERAL. All three of these are refused. =="
probe NegSingle refused '
type T = int where value >= -5
public int Id(T b)
Id(b) -> b'
probe NegAnd refused '
type T = int where value >= -5 and value <= 5
public int Id(T b)
Id(b) -> b'
probe NegOr refused '
type T = int where value >= 1 or value <= -1
public int Id(T b)
Id(b) -> b'

echo "== ...while a relational PATTERN reads the same literal fine. =="
probe NegPattern accepted '
public atom Sign(int n)
Sign(>= 0) -> :nonneg
Sign(<= -1) -> :neg'

echo
echo "== The residuals the algebra hands back for a divisor =="
erl -pa "$root/compiler/_build/default/lib/bsc/ebin" -noshell -eval '
  U = bs_types:subtract(bs_types:int(), bs_types:range(0,0)),
  B = bs_types:subtract(bs_types:range(-10,10), bs_types:range(0,0)),
  io:format("  unbounded int, minus zero : ~s~n", [bs_types:to_pattern(U)]),
  io:format("  -10..10,       minus zero : ~s~n", [bs_types:to_pattern(B)]),
  halt().'
echo "  The second is the one that matters: a BOUNDED divisor's residual names a"
echo "  negative bound, and the probes above show the surface cannot spell it."

echo
if [ "$fails" -eq 0 ]; then
    echo "all 7 probes matched expectation"
else
    echo "$fails probe(s) DIVERGED from what ticket 38 recorded -- re-read before citing"
    exit 1
fi

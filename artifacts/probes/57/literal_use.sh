#!/usr/bin/env bash
# literal_use.sh EBIN LABEL -- once `Delta` is writable, can a program USE a negative literal
# as a Delta?  Return it, pass it, bind it.  (Baseline cannot declare Delta: n/a.)
ebin=$1; label=$2; here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT; echo "## $label"
n=0
use () {  # use LABEL BODY
  n=$((n+1)); mkdir -p "$w/U$n"
  printf 'module U%s\ntype Delta = int where value >= -10 and value <= 10\n%s\n' "$n" "$2" > "$w/U$n/a.bs"
  out=$("$here/bsc.sh" "$ebin" "$w/U$n" 2>&1); rc=$?
  if [ $rc -eq 0 ]; then printf 'ACCEPTED  %s\n' "$1"; else printf 'REFUSED   %-40s %s\n' "$1" "$(printf '%s' "$out" | head -2 | tr '\n' ' ' | sed 's#[^ ]*/a.bs:#a.bs:#')"; fi
}
use 'return a negative literal as Delta'   'public Delta Low()
Low() -> -5'
use 'return a positive literal as Delta (control)' 'public Delta High()
High() -> 5'
use 'pass -5 to a Delta parameter'         'public atom Take(Delta d)
Take(d) -> :ok
public atom Go()
Go() -> Take(-5)'
use 'pass 5 to a Delta parameter (control)' 'public atom Take(Delta d)
Take(d) -> :ok
public atom Go()
Go() -> Take(5)'
use 'pass -50 (outside the domain)'        'public atom Take(Delta d)
Take(d) -> :ok
public atom Go()
Go() -> Take(-50)'
use 'return -0 as Delta'                    'public Delta Z()
Z() -> -0'
# Baseline-expressible version of the same defect (Nz excludes only zero, so -5 IS a member):
n=$((n+1)); mkdir -p "$w/U$n"
printf 'module U%s\ntype Nz = int where value != 0\npublic Nz Neg()\nNeg() -> -5\npublic Nz Pos()\nPos() -> 5\n' "$n" > "$w/U$n/a.bs"
out=$("$here/bsc.sh" "$ebin" "$w/U$n" 2>&1); rc=$?
printf '%-9s %s\n' "$([ $rc -eq 0 ] && echo ACCEPTED || echo REFUSED)" "Nz (value != 0): Neg() -> -5 and Pos() -> 5 :: $(printf '%s' "$out" | head -2 | tr '\n' ' ' | sed 's#[^ ]*/a.bs:#a.bs:#')"
# A provably-zero divisor spelled with a literal minus: ticket 38 §2's refusal should see it.
n=$((n+1)); mkdir -p "$w/U$n"
printf 'module U%s\npublic int D(int x)\nD(x) -> x / -0\n' "$n" > "$w/U$n/a.bs"
out=$("$here/bsc.sh" "$ebin" "$w/U$n" 2>&1); rc=$?
printf '%-9s %s\n' "$([ $rc -eq 0 ] && echo ACCEPTED || echo REFUSED)" "x / -0 (ticket 38: a provably-zero divisor is an error) :: $(printf '%s' "$out" | head -1 | sed 's#[^ ]*/a.bs:#a.bs:#')"
# Arithmetic never gets a precise type, on any build: `value >= 2 + 3` (Prototype B) would be
# readable in a refinement, yet `Take(2 + 3)` against `>= 5` is refused (2 + 3 is typed `int`).
use 'pass 2 + 3 to a `>= 5` parameter'     'type P = int where value >= 5
public atom Take(P p)
Take(p) -> :ok
public atom Go()
Go() -> Take(2 + 3)'

#!/usr/bin/env bash
# probe-table.sh BSC  — the ticket-57 table, then the extensions, against ONE compiler.
# Rows 1-5 are the ticket's own table verbatim (ticket 57 / probe 38b). Rows
# 6+ are extensions; the extension rows exist to find where a fold stops.
# For every accepted refinement a SEMANTIC check follows: the literal just
# inside the bound must compile and the one just outside must be refused, so
# "accepted" cannot be a silent widening to bare int.
set -uo pipefail
BSC=$(readlink -f "${1:?usage: probe-table.sh BSC}")
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
cd "$work"  # bsc drops .abstr/.beam in the cwd
n=0
verdict() { # NAME SRC  -> accepted|refused  (empty stdout == accepted, as 38b)
  mkdir -p "$work/$1"; printf 'module %s\n%s\n' "$1" "$2" > "$work/$1/a.bs"
  out=$("$BSC" "$work/$1/a.bs" 2>&1); rc=$?
  # A `compile:` line comes from erlc AFTER the checker accepted the program. OTP 25's
  # erl_lint rejects a singleton range `3..3` in the emitted -spec ("bad range type");
  # OTP 26+ does not. It is not the checker's verdict, so it is reported apart.
  if [ $rc -eq 0 ] && [ -z "$out" ]; then echo accepted
  elif printf '%s' "$out" | grep -q '^compile:.*bad range type'; then echo "accepted-by-checker(erlc-OTP25-singleton-range)"
  else echo refused; fi
}
clauses() { # "a|b" -> one `K(a) -> :a` clause per alternative
  local IFS='|' p out=""; for p in $1; do out="$out
K($p) -> :a"; done; printf '%s' "$out"; }
refine() { # LABEL PREDICATE COVER SHORT...   (COVER/SHORT: "pat|pat")
  # Semantic check, by exhaustiveness over patterns (which already read negative
  # literals, ticket 57): a clause set COVER must be exhaustive over T, and every
  # SHORT set, which misses exactly one boundary value, must be refused. If T had
  # silently widened to bare int, COVER would be refused; if it were too narrow,
  # a SHORT set would be accepted. Patterns avoid the confound that a literal
  # argument `Id(-1)` is typed int, not -1 (row L1 below).
  local label=$1 pred=$2 cover=${3:-} r name sh; shift 3 2>/dev/null || shift $#
  n=$((n+1)); name="R$n"
  r=$(verdict "$name" "type T = int where $pred
public int Id(T b)
Id(b) -> b")
  printf '%-52s %s\n' "$label  [$pred]" "$r"
  case "$r" in accepted) ;; *) return 0;; esac
  [ -n "$cover" ] || return 0
  printf '      cover  {%s}  %s\n' "$cover" "$(verdict "${name}c" "type T = int where $pred
public atom K(T b)$(clauses "$cover")" | sed 's/^accepted$/ok (exhaustive)/;s/^refused$/WRONG (not exhaustive: type narrower than intended)/')"
  for sh in "$@"; do
    printf '      short  {%s}  %s\n' "$sh" "$(verdict "${name}s${RANDOM}" "type T = int where $pred
public atom K(T b)$(clauses "$sh")" | sed 's/^refused$/ok (refused)/;s/^accepted$/WRONG (accepted: type wider than intended)/')"
  done
}
echo "== ticket 57 table, verbatim =="
refine "T1 int where value >= -5"                    'value >= -5'                      '>= -5'  '>= -4'
refine "T2 -5..5"                                    'value >= -5 and value <= 5'       '>= -5'  '>= -4' '<= 4'
refine "T3 or"                                       'value >= 1 or value <= -1'        '>= 1|<= -1'  '>= 2|<= -1' '>= 1|<= -2'
refine "T4 disjoint, no negative (control)"          'value <= 3 or value >= 10'        '<= 3|>= 10'  '<= 2|>= 10' '<= 3|>= 11'
refine "T5 != 0 (control)"                           'value != 0'                       '>= 1|<= -1'  '>= 2|<= -1' '>= 1|<= -2'
echo
echo "== extensions: where would a fold stop? =="
refine "E1 negative on the LEFT   -5 <= value"       '-5 <= value'                      '>= -5'  '>= -4'
refine "E2 -0"                                       'value >= -0'                      '>= 0'   '>= 1'
refine "E3 double negation  --5"                     'value >= --5'                     '>= 5'   '>= 6'
refine "E4 parenthesised    -(5)"                    'value >= -(5)'                    '>= -5'  '>= -4'
refine "E5 literal arith    2 + 3"                   'value >= 2 + 3'                   '>= 5'   '>= 6'
refine "E6 literal arith    0 - 5"                   'value >= 0 - 5'                   '>= -5'  '>= -4'
refine "E7 literal arith    2 * -3"                  'value >= 2 * -3'                  '>= -6'  '>= -5'
refine "E8 negative equality  value == -3"           'value == -3'                      '-3'     '-2'
refine "E9 negative !="                              'value != -3'                      '>= -2|<= -4'  '>= -1|<= -4' '>= -2|<= -5'
refine "E10 spaced  - 5"                             'value >= - 5'                     '>= -5'  '>= -4'
refine "E11 a variable (must stay refused)"          'value >= n'
echo
echo "== guards: does the same literal in a GUARD behave? (exhaustiveness credit) =="
g() { printf '%-52s %s\n' "$1" "$(verdict "G$((++n))" "$2")"; }
g "G1 'when n >= -5' + 'when n < -5' (exhaustive?)" 'public atom F(int n)
F(n) when n >= -5 -> :a
F(n) when n < -5 -> :b'
g "G2 same with 0 (control; must be accepted)" 'public atom F(int n)
F(n) when n >= 0 -> :a
F(n) when n < 0 -> :b'
g "G3 relational pattern <= -1 (control)" 'public atom F(int n)
F(>= 0) -> :a
F(<= -1) -> :b'
g "G4 'x - 5' still an ordinary subtraction" 'public int F(int x)
F(x) -> x - 5'
g "G5 '0 - 5' still an ordinary subtraction" 'public int F()
F() -> 0 - 5'
g "L1 literal -1 passed to a 'value != 0' param" 'type Nz = int where value != 0
public int Id(Nz b)
public int Go()
Id(b) -> b
Go() -> Id(-1)'
g "L2 literal  1 passed to the same param (control)" 'type Nz = int where value != 0
public int Id(Nz b)
public int Go()
Id(b) -> b
Go() -> Id(1)'
g "L3 guard pair 'n <= -1' / 'n >= 0' (negative literal in a guard)" 'public atom F(int n)
F(n) when n <= -1 -> :neg
F(n) when n >= 0 -> :pos'
g "G6 '-x' still negates a variable" 'public int F(int x)
F(x) -> -x'
g "G7 '-5' as a body value, run result is checked below" 'public int F()
F() -> -5'
echo
echo "== run-time value of a folded expression is unchanged =="
mkdir -p "$work/E"; printf 'module E\npublic int V()\nV() -> -5 + 2 * -(3) - -1\n' > "$work/E/a.bs"
printf '  -5 + 2 * -(3) - -1 evaluates to: %s   (expected -10)\n' "$("$BSC" "$work/E" V 2>&1 </dev/null | tail -1)"

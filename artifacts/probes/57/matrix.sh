#!/usr/bin/env bash
# Run the ticket-57 matrix against each build named in BUILDS (default: base A B C scratch builds).
# base = unmodified compiler; A = parser folds `-<int literal>`; B = checker folds e_neg over a literal
# in comparison/1; C = checker folds + - * over literals.
. "$(dirname "$0")/../lib.sh"
for v in ${BUILDS:-base A B C}; do
  case $v in base) BSC_EBIN=/tmp/bsbuild/ebin;; *) BSC_EBIN=/tmp/bsb_$v/ebin;; esac
  echo "################ $v"
  probe RefNegGe       accepted 'type T = int where value >= -5
public int Id(T x)
Id(x) -> x'
  probe RefNegRange    accepted 'type Delta = int where value >= -100 and value <= 100
public int Id(Delta x)
Id(x) -> x'
  probe RefSumFold     accepted 'type T = int where value >= 2 + 3
public int Id(T x)
Id(x) -> x'
  probe RefVarRhs      refused  'type T = int where value >= value
public int Id(T x)
Id(x) -> x'
  # does the refinement still EXCLUDE (not a silent widening)? calling with out-of-range literal must be refused
  probe RefNegExcludes refused  'type T = int where value >= -5
public int Id(T x)
Id(x) -> x
public int Bad()
Bad() -> Id(-9)'
  probe RefNegAdmits   accepted 'type T = int where value >= -5
public int Id(T x)
Id(x) -> x
public int Ok()
Ok() -> Id(-5)'
  # guard exhaustiveness: no catch-all, partition at -5
  probe GuardNegExh    accepted 'public atom S(int n)
S(n) when n >= -5 -> :a
S(n) when n < -5 -> :b'
  probe PatNegExh      accepted 'public atom S(int n)
S(>= -5) -> :a
S(<= -6) -> :b'
done

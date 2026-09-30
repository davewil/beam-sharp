#!/usr/bin/env bash
# 57c: the same comparand shape in places OTHER than a refinement.
# refine/3 and apply_guard/3 both call alternatives/1, so a guard with `-5` should be unreadable too,
# and (separately) type_of({e_neg,..}) gives `int`, so the literal `-5` is not the interval -5..-5.
. "$(dirname "$0")/common.sh"
show () { # show NAME SRC : print full diagnostics (not just accept/refuse)
  mkdir -p "$work/$1"; printf 'module %s\n%s\n' "$1" "$2" > "$work/$1/a.bs"
  echo "--- $1"; printf '%s\n' "$2" | sed 's/^/  > /'; "$BSC" "$work/$1/a.bs" 2>&1 | sed 's/^/  | /'; echo "  rc=${PIPESTATUS[0]}"; }
echo "== G: guards. non-negative bound (control) vs negative bound =="
show G0 'public atom Sign(int n)
Sign(n) when n >= 0 -> :nonneg
Sign(n) when n < 0  -> :neg'
show G1 'public atom Sign(int n)
Sign(n) when n >= -5 -> :a
Sign(n) when n <= -6 -> :b'
show G2 'public atom Sign(int n)
Sign(n) when n >= 0  -> :nonneg
Sign(n) when n <= -1 -> :neg'
echo "== L: is the literal -5 the interval -5..-5? (compare with 5) =="
show L0 'type Nz = int where value != 0
public int Half(Nz d)
Half(d) -> 100 / d

public int UsePos()
UsePos() -> Half(5)'
show L1 'type Nz = int where value != 0
public int Half(Nz d)
Half(d) -> 100 / d

public int UseNeg()
UseNeg() -> Half(-5)'
show L2 'public int Z()
Z() -> 10 / -0'
echo "== R: the residual IS writable as a pattern, not as a refinement =="
show R0 'public atom F(int n)
F(0) -> :zero'
probe R1 accepted 'type Neg = int where value <= 0 - 1
public int Id(Neg b)
Id(b) -> b'
# NOTE (added after the run, nothing above edited): case R1 was written with expected=accepted in error; V1 had already shown '0 - 1' refused. The output line '!! R1' is my wrong expectation, not a compiler surprise.

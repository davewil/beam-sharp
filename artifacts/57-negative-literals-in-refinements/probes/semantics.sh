#!/usr/bin/env bash
# Usage: semantics.sh [EBIN]  -- what else changes when -5 stops being a node: typing of the literal,
# divisor check (ticket 38), guards, emitted abstract form, runtime values, residual printing.
S=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad
EBIN=${1:-$S/bsc-ebin}; source $S/env.sh
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
bs () { erl -noshell -pa "$EBIN" -run bsc main "$@" -run init stop 2>&1; }
prog () { # Name  -> reads source from stdin into $W/src/Name/a.bs ; out dir $W/out/Name
  mkdir -p "$W/src/$1" "$W/out/$1"; { printf 'module %s\n' "$1"; cat; } > "$W/src/$1/a.bs"; }
compile () { (cd "$W/out/$1" && bs "$W/src/$1/a.bs" | sed "s#$W/src/##" | head -${2:-6}); }

echo "### 1. does the literal -5 have the type -5..-5? (return into a negative refinement; type uses 0 so it is writable today)"
prog Neg <<'X'
type Neg = int where value < 0
public Neg Lit()
public Neg Paren()
public Neg Sub()
Lit() -> -5
Paren() -> (-5)
Sub() -> 0 - 5
X
compile Neg 20 | grep -E "error|^$|returns" 

echo; echo "### 2. ticket 38: provably-zero divisor is refused. Is -0 provably zero?"
prog Div <<'X'
public int Bad(int n)
Bad(n) -> n / -0
public int Bad2(int n)
Bad2(n) -> n / (0 - 0)
public int Bad3(int n)
Bad3(n) -> n / 0
X
compile Div 30 | grep -E "error"

echo; echo "### 3. runtime values (bsc PATH FUNCTION)"
prog Run <<'X'
public int Lit()
Lit() -> -5
public int Dbl()
Dbl() -> -(-5)
public int Sp()
Sp() -> - 5
public int D()
D() -> -7 / 2
public int R()
R() -> -7 % 2
public int M()
M() -> -2 * 3 - 1
public int Big()
Big() -> -99999999999999999999999
public float F()
F() -> -0.0
X
for f in Lit Dbl Sp D R M Big F; do printf '%-4s ' $f; (cd "$W/out/Run" && bs "$W/src/Run/a.bs" $f | tail -1); done

echo; echo "### 4. emitted abstract form of -5 in an expression and in a guard"
prog Emit <<'X'
public int Lit()
Lit() -> -5
public atom Sign(int n)
Sign(n) when n <= -1 -> :neg
Sign(n) -> :other
X
compile Emit >/dev/null
grep -A3 "^{function,0,'Lit'" "$W/out/Emit/Emit.abstr" | tr -s ' \n' ' '; echo
grep -B1 -A1 "'=<'" "$W/out/Emit/Emit.abstr" | tr -s ' \n' ' '; echo

echo; echo "### 5. guard with a negative literal and no catch-all (baseline: reported as non-exhaustive)"
prog Guard <<'X'
public atom Sign(int n)
Sign(n) when n <= -1 -> :neg
Sign(n) when n >= 0 -> :nonneg
X
compile Guard 6
echo "-- same program with n < 0 (control: must be accepted on every build)"
prog Guard2 <<'X'
public atom Sign(int n)
Sign(n) when n < 0 -> :neg
Sign(n) when n >= 0 -> :nonneg
X
compile Guard2 6; echo "(empty above = accepted)"

echo; echo "### 6. residual of a bounded signed domain"
erl -noshell -pa "$EBIN" -eval 'B = bs_types:subtract(bs_types:range(-10,10), bs_types:range(0,0)), io:format("subtract(-10..10, 0) prints: ~s~n",[bs_types:to_pattern(B)]), halt().'
prog Res <<'X'
type D = int where value >= -10 and value <= 10
public atom Sg(D n)
Sg(0) -> :zero
Sg(>= 1) -> :pos
X
compile Res 6

#!/usr/bin/env bash
# 05 -- what the choice does OUTSIDE a refinement: the type of `-5` as an
# expression, ticket 38's provably-zero divisor, and whether any variant changes
# a program's VALUE. Variants: base g1 g1b c1 c2 (see 00_build.sh).
#
# Predictions written before the run:
#   N2  `G(-5)` into a `value != 0` parameter: base refused (e_neg is typed
#       `int`, which contains 0); g1 accepted; g1b refused; c1 refused; c2 accepted.
#       REFUTES the prediction that the type of -5 matters: base ACCEPTING it.
#   N5  `x / -0`: base accepted (not "provably zero"); g1 refused; others accepted.
#   DIFF every program's printed value is identical in every variant.
#       REFUTES "folds preserve meaning": any differing line.
. "$(dirname "$0")/lib.sh"
printf '%-52s %-9s %-9s %-9s %-9s %-9s\n' case base g1 g1b c1 c2
row () { local label=$1; local src=$2; shift 2; local cells="" v exp
  for v in base g1 g1b c1 c2; do probe $v X "$src"; exp=$1; shift
    if [ "$verdict" = "$exp" ]; then cells="$cells $(printf '%-9s' $verdict)"; else cells="$cells $(printf '%-9s' "$verdict!=$exp")"; fi
  done; printf '%-52s%s\n' "$label" "$cells"; }
A=accepted; R=refused
NZ='type Nz = int where value != 0
int G(Nz b)
G(b) -> b
'
row 'N1 G(5) into Nz'                 "$NZ
public int F()
F() -> G(5)"           $A $A $A $A $A
row 'N2 G(-5) into Nz'                "$NZ
public int F()
F() -> G(-5)"          $R $A $R $R $A
row 'N3 G(0 - 5) into Nz'             "$NZ
public int F()
F() -> G(0 - 5)"       $R $R $R $R $R
row 'N7 G(- -5) into Nz'              "$NZ
public int F()
F() -> G(- -5)"        $R $A $R $R $R
row 'N5 x / -0 (ticket 38: provably-zero divisor)' 'public int F(int x)
F(x) -> x / -0'        $A $R $A $A $A
row 'N6 x / 0'                        'public int F(int x)
F(x) -> x / 0'         $R $R $R $R $R
row 'N8 x % -0'                       'public int F(int x)
F(x) -> x % -0'        $A $R $A $A $A
P5='type P = int where value >= 0 and value <= 100
int G(P b)
G(b) -> b
'
row 'N9 return -1 where a Pos is declared'  'type Pos = int where value >= 1
public Pos F()
F() -> -1'             $R $R $R $R $R
echo
echo "# DIFF: one program, every variant, printed values (raw):"
cat > "$OUT/diff_prog.bs" <<'BS'
module Diff

public int A()
A() -> - -5
public int B()
B() -> -(2 + 3)
public int C()
C() -> 1 - -5
public int D()
D() -> -5 * 3
public int E()
E() -> - 2 * 3
public int F()
F() -> 10 - -5 - -5
public int G(int x)
G(x) -> -x - -5
public int H()
H() -> -0
public atom I(int n)
I(-5) -> :five
I(n) when n >= -4 -> :ge
I(_) -> :lt
BS
for v in base g1 g1b c1 c2; do
  mkdir -p "$OUT/diff/$v/Diff"; cp "$OUT/diff_prog.bs" "$OUT/diff/$v/Diff/a.bs"
  { for call in "A" "B" "C" "D" "E" "F" "G 3" "H" "I -5" "I -4" "I -9"; do
      printf '%s => ' "$call"; "$(bsc_of $v)" -o "$OUT/diff/$v" "$OUT/diff/$v/Diff/a.bs" $call 2>&1 | head -2 | tr '\n' ' ' | sed "s|$OUT/diff/$v/Diff/||g"; echo; done; } > "$OUT/diff/$v.txt"
done
paste -d'|' "$OUT/diff/base.txt" "$OUT/diff/g1.txt" | head -3 >/dev/null
grep -q "error" "$OUT/diff/base.txt" && echo "INVALID  the diff program does not compile on base; nothing below means anything"
for v in g1 g1b c1 c2; do
  if diff -q "$OUT/diff/base.txt" "$OUT/diff/$v.txt" >/dev/null; then echo "MATCH    printed values identical base vs $v"; else echo "REFUTED  printed values differ base vs $v"; diff "$OUT/diff/base.txt" "$OUT/diff/$v.txt" | head -20; fi
done
cat "$OUT/diff/base.txt"

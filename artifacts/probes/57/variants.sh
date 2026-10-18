#!/bin/bash
# Runs the ticket-57 questions against baseline, checker-fold and parser-fold builds.
# Variants are scratch copies of compiler/src with the 1-3 line patches in proto/.
. "$(dirname "$0")/../env.sh"
mk() { mkdir -p $1; cat > $1/$1.bs; }
for v in c c57_checker c57_parser; do
  export BSC_EBIN=$S/$v/ebin
  echo "=================== variant: $v"
  work 57v
  mk A <<'B'
module A
type Delta = int where value >= -100 and value <= 100
public int F(Delta d)
F(d) -> d
B
  echo "-- refinement Delta = -100..100:"; bsc --src-root . A F -7 2>&1 | head -1 | cut -c1-80
  mk G <<'B'
module G
public atom H(int n)
H(n) when n >= -5 -> :hi
H(n) when n < -5 -> :lo
B
  echo "-- two guards over -5 (exhaustive?):"; bsc --src-root . G H -9 2>&1 | head -1 | cut -c1-80
  mk Q <<'B'
module Q
public int Neg()
Neg() -> -5
public int Min()
Min() -> -9223372036854775808
public int Dbl()
Dbl() -> - -5
B
  echo "-- emitted -5 / min_int / --5 evaluate to:"; for f in Neg Min Dbl; do printf "%s=" $f; bsc --src-root . Q $f 2>&1 | head -1; done
  echo "-- what -5 compiles to in the .abstr (negative literal vs unary op):"; grep -o "{op,[0-9]*,'-',{integer,[0-9]*,5}}\|{integer,[0-9]*,-5}" -r . 2>/dev/null | sort | uniq -c | head -3
done

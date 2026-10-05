#!/usr/bin/env bash
# p02 -- Can a forged value reach a private function through an exported one, and does the exported
# function's OWN guard already catch it?  Built for each of base / a / b / c.
# Claims tested (ticket 59 "It is not [a defect]" paragraph + F24 section 3):
#   T1  a forged record handed to an exported function IS caught by that function's own tag test
#       when the record is the whole parameter (C2: raising function = Top, not Amount)      [refutes the claim "reaches private unchallenged" for top-level params]
#   T2  a forged record one projection down (list element) reaches the private function; today only the
#       private tag test stops it (C4: raising function = Amount)
#   T3  the int analogue: a float/out-of-range element reaches a private function SILENTLY today (C7, C8)
# REFUTED if: C2 under base raises in Amount (then the exported guard does not catch it), OR C4 under base
# does not raise in Amount (then the private tag test is dead weight there), OR C7/C8 under base raise.
. "$(dirname "$0")/lib.sh"; cd "$HERE"
for v in base a b c; do
  O="$OUT/p02/$v"; rm -rf "$O"; mkdir -p "$O"
  "$(bscv $v)" -o "$O" src/Deep > "$O/bsc.log" 2>&1 || { echo "compile failed $v"; cat "$O/bsc.log"; exit 1; }
  ./pp.escript "$O/Deep.abstr" > "$O/emitted.erl"
  ./drive_deep.escript "$O" > "$O/run.txt" 2>&1
  echo "=============== variant $v"; cat "$O/run.txt"
done
echo "## assertions"
B="$OUT/p02/base/run.txt"
sed -n '/^C2/,/^C3/p' "$B" > "$OUT/p02/base_c2.txt"; sed -n '/^C4/,/^C5/p' "$B" > "$OUT/p02/base_c4.txt"
sed -n '/^C7/,/^C8/p' "$B" > "$OUT/p02/base_c7.txt"; sed -n '/^C8/,/^C9/p' "$B" > "$OUT/p02/base_c8.txt"
expect "T1 base: forged Order at Top is refused BY Top (exported tag test)" "$OUT/p02/base_c2.txt" "function_clause,\{'Deep','Top',1\}"
expect "T2 base: forged element refused BY private Amount"                  "$OUT/p02/base_c4.txt" "function_clause,\{'Deep','Amount',1\}"
expect "T3a base: float element returns silently"                           "$OUT/p02/base_c7.txt" "\{ok,[0-9]"
expect "T3b base: out-of-range int element returns silently"               "$OUT/p02/base_c8.txt" "\{ok,[0-9]"
for v in a b c; do sed -n '/^C4/,/^C5/p' "$OUT/p02/$v/run.txt" > "$OUT/p02/${v}_c4.txt"; sed -n '/^C7/,/^C8/p' "$OUT/p02/$v/run.txt" > "$OUT/p02/${v}_c7.txt"; done
expect "a: forged element is NOT refused (silent {ok,14})"  "$OUT/p02/a_c4.txt" "\{ok,14\}"
expect "b: forged element refused by Amount"               "$OUT/p02/b_c4.txt" "function_clause,\{'Deep','Amount',1\}"
expect "c: forged element refused by Amount (test kept: caller is one projection down)" "$OUT/p02/c_c4.txt" "function_clause,\{'Deep','Amount',1\}"
expect "b: float element refused by private Weight"        "$OUT/p02/b_c7.txt" "function_clause,\{'Deep','Weight',1\}"
expect "c: float element refused by private Weight"        "$OUT/p02/c_c7.txt" "function_clause,\{'Deep','Weight',1\}"
for v in base a b c; do sed -n '/^C12/,$p' "$OUT/p02/$v/run.txt" > "$OUT/p02/${v}_c12.txt"; done
expect "base: C12 float through List.Map reaches private Twice silently ([2,3.0])" "$OUT/p02/base_c12.txt" "\{ok,\[2,3.0\]\}"
expect "a:    C12 silent"                              "$OUT/p02/a_c12.txt" "\{ok,\[2,3.0\]\}"
expect "b:    C12 refused by private Twice"            "$OUT/p02/b_c12.txt" "function_clause,\{'Deep','Twice',1\}"
expect "c:    C12 refused by private Twice"            "$OUT/p02/c_c12.txt" "function_clause,\{'Deep','Twice',1\}"
echo "p02 FAILS=$FAILS"; exit $FAILS

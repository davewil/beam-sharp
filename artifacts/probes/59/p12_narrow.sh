#!/usr/bin/env bash
# p12 -- F24 section 6 (ENG-330): a private int helper fed through a narrowing guard was once reached by an
# atom ("Privacy is what makes it silent"). Is it still silent on the current compiler?  Asserts the FIXED
# behaviour (clause 2 takes it: 0).  REFUTES "fixed" if Bump(:foo) returns :foo.
. "$(dirname "$0")/lib.sh"; cd "$HERE"
O="$OUT/p12"; rm -rf "$O"; mkdir -p "$O"
for v in base b; do
  "$(bscv $v)" -o "$O/$v" src/Narrow Bump :foo > "$O/$v.foo.txt" 2>&1
  "$(bscv $v)" -o "$O/$v" src/Narrow Bump 5   > "$O/$v.five.txt" 2>&1
  echo "$v: Bump(:foo) -> $(tail -1 "$O/$v.foo.txt")   Bump(5) -> $(tail -1 "$O/$v.five.txt")"
done
expect "base: Bump(:foo) -> 0 (no atom crosses the 'public int' boundary)" "$O/base.foo.txt" "^0$"
expect "base: Bump(5) -> 5" "$O/base.five.txt" "^5$"
echo "p12 FAILS=$FAILS"; exit $FAILS

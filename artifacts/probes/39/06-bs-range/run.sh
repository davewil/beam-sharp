#!/usr/bin/env bash
# (1) Does bs_check synthesise a range for arithmetic?  (2) Do exported refined params reach the optimiser?
source "$(dirname "$0")/../common.sh"; cd "$(dirname "$0")"; rm -rf out; mkdir out
echo "== (1) declaring Wrap's result 0..99, body = the benchmark's arithmetic"
$BSC -o out/narrow Narrow 2>&1 | head -20
echo; echo "== bs_check source, the arithmetic rule (compiler/src/bs_check.erl)"
grep -n "Arithmetic returns\|Arithmetic synthesises" -A1 "$REPO/compiler/src/bs_check.erl"
grep -n "^op_type('%')\|^op_type('+')" "$REPO/compiler/src/bs_check.erl"
echo; echo "== (2) exported Twice(Digit) vs Plain(int): emitted forms and assembler"
$BSC -o out/pub Pub 2>&1 | head
grep -n "'Twice'" -B1 -A12 out/pub/Pub.abstr | grep -n "function\|op,\|'>='\|'=<'\|integer,{" | head -12
( cd out/pub && erlc +from_abstr -S Pub.abstr 2>&1 | head -3 )
for f in Twice Plain; do echo "-- $f"; awk '/^\{function, *.'$f'., *1/{p=1} p{print} p&&/return/{exit}' out/pub/Pub.S | grep -E "tr,|var_info|gc_bif|is_" ; done

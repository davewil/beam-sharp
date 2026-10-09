#!/usr/bin/env bash
# Ticket §2 claim: "beam-sharp KNOWS the 0..99 fact in a stronger form and throws it away at the emission boundary".
# Test what the checker actually knows, and what reaches the emitted code.
. "$(dirname "$0")/env.sh"; S=$A/probes/src
echo "### (a) Can B# prove Wrap : int -> Dial (0..99) when the body is rem(rem(n,100)+100,100)?   [Dial01]"
echo; echo "### (b) Does the checker carry a range through  d + 1  under the guard d < 99 ?   [Dial02]"
$BSC -o $W/p11b $S/Dial02 2>&1 | head -8
echo; echo "### (c) Refined parameter: exported vs private. What is emitted, and what does the OTP analyser make of it?   [Dial03]"
$BSC -o $W/p11c $S/Dial03 2>&1 | head
erl -noshell -pa $W -eval 'dis:main(["'$W'/p11c/Dial03.beam"])' | grep -v "^  {\(line\|label\)" | sed -n '/Next.\/2/,/module_info\/0/p'
echo; echo "### (d) the emitted -spec for the refined parameter"
grep -n "range" $W/p11c/Dial03.abstr | head -4

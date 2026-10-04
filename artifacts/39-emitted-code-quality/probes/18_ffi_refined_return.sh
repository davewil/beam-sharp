#!/usr/bin/env bash
# Option C check: when an FFI declaration returns a refined type, what does bsc emit at the call, and what does OTP make of it?
. "$(dirname "$0")/env.sh"; S=$A/probes/src
erlc -o $W/p18 $S/lib08.erl 2>/dev/null || { mkdir -p $W/p18; erlc -o $W/p18 $S/lib08.erl; }
$BSC -o $W/p18 $S/Ffi18 2>&1 | head -12
[ -f $W/p18/Ffi18.beam ] && erl -noshell -pa $W -eval 'dis:main(["'$W'/p18/Ffi18.beam"])' | grep -v "^  {\(line\|label\)" | sed -n '/Refined/,/module_info\/0/p'
grep -n "is_integer" -B2 -A8 $W/p18/Ffi18.abstr 2>/dev/null | sed -n 1,40p

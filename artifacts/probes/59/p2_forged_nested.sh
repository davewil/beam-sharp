#!/bin/sh
D=$(cd "$(dirname "$0")" && pwd); BSC=${BSC:?set BSC}; W=${PROBE_TMP:-$(mktemp -d)}
"$BSC" -o "$W" "$D/bs/Nested" || exit 2
echo '--- emitted heads'; "$D/../dump_abstr.escript" "$W/Nested.abstr" PrivTotal ViaTuple ViaList Direct Inline
F="{ Kind = :'Other.Order', Id = 1, Total = 999 }"
echo "--- run with a FORGED record (wrong Kind): $F"
printf 'Direct  : '; "$BSC" "$D/bs/Nested" Direct "$F" 2>&1 | tail -1
printf 'ViaTuple: '; "$BSC" "$D/bs/Nested" ViaTuple "($F, 1)" 2>&1 | tail -1
printf 'ViaList : '; "$BSC" "$D/bs/Nested" ViaList "[$F]" 2>&1 | tail -1
printf 'Inline  : '; "$BSC" "$D/bs/Nested" Inline "($F, 1)" 2>&1 | tail -1
echo "--- the same question for the int test: a float / out-of-range value nested in a tuple, handed to a private Octet parameter"
printf 'OctetDirect(100.5)        : '; "$BSC" "$D/bs/Nested" OctetDirect 100.5 2>&1 | tail -1
printf 'OctetViaTuple((100.5, 1)) : '; "$BSC" "$D/bs/Nested" OctetViaTuple "(100.5, 1)" 2>&1 | tail -1
printf 'OctetViaTuple((300, 1))   : '; "$BSC" "$D/bs/Nested" OctetViaTuple "(300, 1)" 2>&1 | tail -1

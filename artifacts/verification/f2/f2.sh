#!/bin/sh
export BSC=/home/user/beam-sharp/compiler/_build/default/bin/bsc; . /home/user/beam-sharp/artifacts/probes/env.sh
P=/home/user/beam-sharp/artifacts/probes
N=$P/59/bs/Nested
W=$(mktemp -d)
$BSC -o $W $N || exit 2
run() { f=$1; shift; printf '### %s %s\n' "$f" "$*"; $BSC $N $f "$@" 2>&1 | head -12; echo "[exit=$?]"; echo; }
GOOD="{ Id = 1, Total = 5 }"
WK="{ Kind = :'Other.Order', Id = 1, Total = 999 }"
MF="{ Kind = :'Nested.Order', Id = 1 }"
OK="{ Kind = :'Nested.Order', Id = 1, Total = 5 }"
echo "=== sanity with valid inputs"
run Direct "$OK"; run ViaTuple "($OK, 1)"; run ViaList "[$OK]"; run Inline "($OK, 1)"; run OctetDirect 100; run OctetViaTuple "(100, 1)"
echo "=== wrong Kind"
run Direct "$WK"; run ViaTuple "($WK, 1)"; run ViaList "[$WK]"; run Inline "($WK, 1)"
echo "=== missing field, right Kind"
run Direct "$MF"; run ViaTuple "($MF, 1)"; run ViaList "[$MF]"; run Inline "($MF, 1)"
echo "=== non-map"
run Direct 5; run ViaTuple "(5, 1)"; run ViaList "[5]"; run Inline "(5,1)"
echo "=== floats / ints"
run OctetDirect 100.5; run OctetViaTuple "(100.5, 1)"; run OctetDirect 300; run OctetViaTuple "(300, 1)"; run OctetDirect -1; run OctetViaTuple "(-1, 1)"; run OctetViaTuple ":a"; run OctetViaTuple "(:a, 1)"
echo "=== emitted"
$P/dump_abstr.escript $W/Nested.abstr

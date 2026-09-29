#!/bin/sh
# PROBE 6b — a real compile of two colliding names.
# usage: p6b_collision.sh PLAIN_BSC_SH ALIAS_EBIN OUTDIR
# EXPECTED (before run):
#   with the reference compiler (no aliases) Coll compiles (exit 0) and exports 'GetX' and 'Get_x'.
#   with the alias compiler copy (BS_ALIAS=wrapper) compilation FAILS, the failure names the alias
#   `get_x` and both authors' names -- but as a raw Erlang crash {alias_collision,...} from the
#   experimental patch, NOT a B# diagnostic (the experiment has no bs_diag term).
HERE=$(cd "$(dirname "$0")" && pwd); PLAIN=$1; EBIN=$2; OUT=$3; mkdir -p "$OUT/plain" "$OUT/alias"
$PLAIN -o "$OUT/plain" "$HERE/src/Coll/coll.bs" >"$OUT/plain.log" 2>&1; PS=$?
BS_ALIAS=wrapper "$HERE/bsc-with.sh" "$EBIN" -o "$OUT/alias" "$HERE/src/Coll/coll.bs" >"$OUT/alias.log" 2>&1; AS=$?
echo "reference compiler exit=$PS ; alias compiler exit=$AS"
grep -o "alias_collision[^}]*}" "$OUT/alias.log" | head -1
if [ $PS -eq 0 ] && [ $AS -ne 0 ] && grep -q "alias_collision,get_x,1,\['GetX','Get_x'\]" "$OUT/alias.log"; then echo "PASS p6b"; else echo "FAIL p6b"; head -5 "$OUT/alias.log"; fi

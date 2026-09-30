#!/usr/bin/env bash
# P2: a value the exported boundary does not guard (one projection deep) reaches a private
# function. Which private guard, if any, objects?
source "$(dirname "$0")/env.sh"
EBIN=${1:-/tmp/bs59-build/ebin-base}; [ -d "$EBIN" ] || build_compiler "$EBIN"
OUT=$(mktemp -d); mkdir -p "$OUT/P2"; cp "$PROBES/src/p2_forged_projection.bs" "$OUT/P2/p2.bs"
bsc_in "$EBIN" "$OUT" --src-root "$OUT" "$OUT/P2" 2>&1 | grep -v '^$'
B=$(dirname "$(ls "$OUT"/P2.beam "$OUT"/P2/P2.beam 2>/dev/null | head -1)")
C() { "$PROBES/call.escript" "$B" P2 "$1"; }
FORGED_INV="#{'Kind' => 'P2.Invoice', 'Id' => 1, 'Total' => 9}"
GOOD_ORD="#{'Kind' => 'P2.Order', 'Id' => 1, 'Total' => 9}"
echo "--- honest values"
C "M:'ViaRec'({$GOOD_ORD, 1})"
C "M:'ViaInt'({7, 1})"
echo "--- forged record (an Invoice where an Order is declared), one tuple deep"
C "M:'ViaRec'({$FORGED_INV, 1})"
C "M:'DirectRec'({$FORGED_INV, 1})"
echo "--- forged record, whole parameter (control: the exported tag test fires)"
C "M:'WholeRec'($FORGED_INV)"
echo "--- a float where int is declared, one tuple deep, through a private int function"
C "M:'ViaInt'({1.5, 1})"
C "M:'ViaInt'({foo, 1})"

#!/usr/bin/env bash
# P3: a private function escapes as a fun value (F46). Is "every call site of a private
# function is a checked B# call site" (18 §4, F24 §2, F37 §1) still true?
source "$(dirname "$0")/env.sh"
EBIN=${1:-/tmp/bs59-build/ebin-base}; [ -d "$EBIN" ] || build_compiler "$EBIN"
OUT=$(mktemp -d); mkdir -p "$OUT/P3"; cp "$PROBES/src/p3_fn_value_escape.bs" "$OUT/P3/p3.bs"
bsc_in "$EBIN" "$OUT" --src-root "$OUT" "$OUT/P3" 2>&1 | grep -v '^$'
B=$(dirname "$(ls "$OUT"/P3.beam "$OUT"/P3/P3.beam 2>/dev/null | head -1)")
echo "--- emitted heads"; "$PROBES/dump.escript" "$B/P3.beam"
echo "--- the escaped fun, applied by an Erlang caller"
C() { "$PROBES/call.escript" "$B" P3 "$1"; }
C "F = M:'Rule'(staff), {erlang:fun_info(F, type), erlang:fun_info(F, module), F(7)}"
C "F = M:'Rule'(staff), F(1.5)"
C "F = M:'Rule'(staff), F(foo)"
C "F = M:'Reader'(total), F(#{'Kind' => 'P3.Order', 'Id' => 1, 'Total' => 9})"
C "F = M:'Reader'(total), F(#{'Kind' => 'P3.Invoice', 'Id' => 1, 'Total' => 9})"
C "F = M:'Reader'(total), F(5)"

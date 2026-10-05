#!/usr/bin/env bash
# p07 -- Elixir: does the compiler treat defp differently from def for guards/patterns?
# Elixir sources are NOT installed (beams only), so this is behaviour only: compile + disassemble.
# REFUTED (that Elixir applies one rule to both) if the defp functions lose a guard/pattern the def has
# for a reason other than erlc's beam_ssa_type (priv_int called from run_proven with a proven integer).
. "$(dirname "$0")/lib.sh"; cd "$HERE"
O="$OUT/p07"; rm -rf "$O"; mkdir -p "$O"
elixir --version 2>&1 | tail -2 | tee "$O/version.txt"
elixirc -o "$O" src/elixir/scope.ex 2>&1 | tee "$O/elixirc.log"
./dis.escript "$O/Elixir.Scope.beam" 'pub_rec/1' 'priv_rec/1' 'pub_int/1' 'priv_int/1' 'run_proven/1' 'only_proven/1' > "$O/disasm.txt"; cat "$O/disasm.txt"
for f in pub_rec priv_rec pub_int priv_int; do sed -n "/^== $f\//,/^== /p" "$O/disasm.txt" | sed '$d' > "$O/$f.txt" || true; done
sed -n "/^== priv_rec/,/^== pub_int/p" "$O/disasm.txt" > "$O/priv_rec.txt"
sed -n "/^== pub_int/,/^== priv_int/p" "$O/disasm.txt" > "$O/pub_int.txt"
sed -n "/^== priv_int/,/^== run_proven/p" "$O/disasm.txt" > "$O/priv_int.txt"
sed -n "/^== pub_rec/,/^== priv_rec/p" "$O/disasm.txt" > "$O/pub_rec.txt"
expect "def pub_rec keeps the struct tag test"   "$O/pub_rec.txt"  "is_eq_exact|'Elixir.Scope.Order'"
expect "defp priv_rec keeps the struct tag test" "$O/priv_rec.txt" "is_eq_exact|'Elixir.Scope.Order'"
expect "def pub_int keeps is_integer"            "$O/pub_int.txt"  "is_integer"
sed -n "/^== only_proven/,\$p" "$O/disasm.txt" | sed -n '1,/return/p' > "$O/only_proven.txt"
expect "defp priv_int keeps is_integer: it is ALSO captured as &priv_int/1 in run/1" "$O/priv_int.txt" "is_integer"
expect "(non-vacuous) only_proven slice holds the function body" "$O/only_proven.txt" "gc_bif,.\*."
absent "defp only_proven (sole caller proves integer, no capture): is_integer elided by erlc" "$O/only_proven.txt" "test,is_integer"
echo "p07 FAILS=$FAILS"; exit $FAILS

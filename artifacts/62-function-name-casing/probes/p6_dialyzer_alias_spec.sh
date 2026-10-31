#!/usr/bin/env bash
# Probe 6: does a spec-less snake_case trampoline lose Dialyzer's contract check?
# Run: bash p6_dialyzer_alias_spec.sh   (builds a small PLT: erts kernel stdlib; ~minutes)
# Asserts: the PascalCase misuse IS reported (control); then reports whether the alias
# misuse is reported. Exit 1 only if the control fails (probe would be vacuous).
set -u
cd "$(dirname "$0")/dia"
D=$(mktemp -d); trap 'rm -rf "$D"' EXIT
erlc -o "$D" +debug_info dm.erl || exit 2
dialyzer --build_plt --output_plt "$D/plt" --apps erts kernel stdlib >/dev/null 2>&1
dialyzer --plt "$D/plt" "$D/dm.beam" 2>&1 | tee "$D/out"
grep -q "bad_pascal" "$D/out" || { echo "CONTROL FAILED: misuse of spec'd PascalCase fn not reported"; exit 1; }
for f in bad_alias bad_alias2; do
  if grep -q "$f" "$D/out"; then echo "OBSERVED: $f -> reported"; else echo "OBSERVED: $f -> NOT reported"; fi
done

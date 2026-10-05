#!/usr/bin/env bash
# p10 -- how many private functions in compiler/examples gain or lose a guard under each option.
# Every module directory under compiler/examples (exemplars/ do not compile: no `module` line, listed below)
# is compiled with base / a / b / c; the emitted Erlang forms are then counted (census.escript) for guard
# conjuncts of the three shapes bsc emits, split exported/private.  Also sums Code-chunk bytes.
# REFUTES "this ticket is about few functions" if priv_fns_tested is tiny; REFUTES the option-c prototype's
# value if c == b everywhere.
. "$(dirname "$0")/lib.sh"; cd "$REPO/compiler"
O="$OUT/p10"; rm -rf "$O"; mkdir -p "$O"
find examples -path examples/exemplars -prune -o -name '*.bs' -print0 | while IFS= read -r -d '' f; do dirname "$f"; done | sort -u > "$O/modules.txt"
echo "modules: $(wc -l < "$O/modules.txt")"
for d in examples/exemplars/*/; do echo "exemplar $d: $("$(bscv base)" --src-root examples -o "$O/ex" "$d" 2>&1 | head -1)"; done | tee "$O/exemplars.txt"
for v in base a b c; do
  mkdir -p "$O/$v"; n=0; ok=0
  while IFS= read -r d; do
    n=$((n+1)); mkdir -p "$O/$v/$n"
    if "$(bscv $v)" --src-root examples -o "$O/$v/$n" "$d" > "$O/$v/$n/bsc.log" 2>&1; then ok=$((ok+1)); echo "$d" > "$O/$v/$n/name"; fi
  done < "$O/modules.txt"
  echo "variant $v: compiled $ok/$n modules"
  # a dotted module compiled as a dependency of another directory is emitted again: dedupe by module name
  mkdir -p "$O/$v/all"; for f in "$O/$v"/*/*.abstr "$O/$v"/*/*.beam; do cp "$f" "$O/$v/all/"; done
  ls "$O/$v"/all/*.abstr > "$O/$v/files.txt"; echo "$v  distinct modules: $(wc -l < "$O/$v/files.txt")"
  "$HERE/census.escript" $(cat "$O/$v/files.txt") > "$O/$v/census.txt"
  tail -1 "$O/$v/census.txt" | sed "s/^/$v  /"
  tot=0; for b in "$O/$v"/all/*.beam; do c=$("$HERE/bytes_one.escript" "$b" | sed 's/code=\([0-9]*\).*/\1/'); tot=$((tot+c)); done; echo "$v  total Code-chunk bytes over all beams: $tot" | tee -a "$O/$v/census.txt"
done
echo "## modules whose private-function guard count differs from base (priv_tag/priv_int/priv_flt per module)"
for v in a b c; do
  echo "-- $v vs base"
  join <(awk '{print $1, $3, $5, $7, $9, $10}' "$O/base/census.txt" | sed 's/[a-z_]*=//g' | sort) \
       <(awk '{print $1, $3, $5, $7, $9, $10}' "$O/$v/census.txt" | sed 's/[a-z_]*=//g' | sort) | awk '$2!=$7||$3!=$8||$4!=$9||$5!=$10||$6!=$11 {print}'
done | tee "$O/deltas.txt"
echo "p10 done"

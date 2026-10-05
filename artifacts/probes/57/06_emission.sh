#!/usr/bin/env bash
# 06 -- does a fold change the EMITTED guard? Same source file, same path,
# every variant, then (a) diff the .abstr, (b) compare the compiled BEAM code
# (beam_disasm code chunk, so debug_info/abstract-code differences are not in it).
# Prediction: only g1 changes the abstract form ({op,'-',{integer,5}} becomes
# {integer,-5}); the compiled code is identical in all variants, because the
# Erlang compiler folds the unary minus itself (sys_core_fold, see brief).
# REFUTES the prediction: a differing disassembly between any two variants.
. "$(dirname "$0")/lib.sh"
src=$OUT/emit/Emit/a.bs; mkdir -p "$(dirname $src)"
cat > "$src" <<'BS'
module Emit

public atom Band(int n)
Band(n) when n >= -5 -> :a
Band(n) -> :b

public int Neg(int x)
Neg(x) -> x - -5
BS
cat > "$OUT/disasm.escript" <<'ES'
#!/usr/bin/env escript
main([F]) -> {beam_file, _M, Ex, _A, _C, Code} = beam_disasm:file(F),
  io:format("~p~n~p~n", [lists:sort(Ex), Code]).
ES
for v in base g1 g1b c1 c2; do
  mkdir -p "$OUT/emit/$v"; "$(bsc_of $v)" -o "$OUT/emit/$v" "$src" > "$OUT/emit/$v/compile.txt" 2>&1
  escript "$OUT/disasm.escript" "$OUT/emit/$v/Emit.beam" > "$OUT/emit/$v/code.txt" 2>&1
  grep -A3 "'>='" "$OUT/emit/$v/Emit.abstr" | head -5 > "$OUT/emit/$v/guard_fragment.txt"
done
for v in base g1 g1b c1 c2; do
  n=$(grep -c is_ge "$OUT/emit/$v/code.txt"); [ "$n" -ge 1 ] && echo "MATCH    $v compiled to an is_ge test ($n)" || echo "INVALID  $v produced no is_ge test; the identity checks below are vacuous"
done
for v in g1 g1b c1 c2; do
  if cmp -s "$OUT/emit/base/Emit.abstr" "$OUT/emit/$v/Emit.abstr"; then a=identical; else a=DIFFERENT; fi
  if cmp -s "$OUT/emit/base/code.txt" "$OUT/emit/$v/code.txt"; then c=identical; else c=DIFFERENT; fi
  printf '%-4s abstr vs base: %-10s  disassembled code vs base: %s\n' $v $a $c
done
echo "# guard fragment, base:"; cat "$OUT/emit/base/guard_fragment.txt"
echo "# guard fragment, g1:";   cat "$OUT/emit/g1/guard_fragment.txt"
echo "# the abstr diff base -> g1 (raw):"; diff "$OUT/emit/base/Emit.abstr" "$OUT/emit/g1/Emit.abstr"
echo "# disassembly of Band/1 (base), proving the compiled guard is a compare against the constant -5:"
grep -n "gc_bif\|is_ge\|-5" "$OUT/emit/base/code.txt" | head -8

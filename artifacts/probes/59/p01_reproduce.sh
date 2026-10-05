#!/usr/bin/env bash
# p01 -- REPRODUCE ticket 59's measurement on the repo's own bsc.
# Claim: bs_emit:boundary_guards puts the record TAG test on a private function and the
#        int KIND test only on exported functions.
# REFUTED if: private InnerRec/1 has no Kind test in its emitted Erlang or its beam, OR
#        private InnerInt/1 carries is_integer in the emitted Erlang, OR exported OuterInt lacks it.
. "$(dirname "$0")/lib.sh"; cd "$HERE"
O="$OUT/p01"; rm -rf "$O"; mkdir -p "$O"
echo "## source lines read (bs_emit.erl):" | tee "$O/lines.txt"
sed -n '275,293p' "$REPO/compiler/src/bs_emit.erl" | nl -v275 -ba | tee -a "$O/lines.txt"
"$REPO_BSC" -o "$O" src/Scope > "$O/bsc.log" 2>&1; cat "$O/bsc.log"
./pp.escript "$O/Scope.abstr" > "$O/emitted.erl"
grep -E "^'(OuterRec|InnerRec|OuterInt|InnerInt)'\(" -A3 "$O/emitted.erl" | grep -v '^-spec' | tee "$O/emitted_heads.txt"
./dis.escript "$O/Scope.beam" 'InnerRec/1' 'InnerInt/1' 'OuterRec/1' 'OuterInt/1' > "$O/disasm.txt"; cat "$O/disasm.txt"
echo "## assertions"
sed -n "/^== 'InnerRec'/,/^== 'OuterInt'/p" "$O/disasm.txt" > "$O/innerrec_dis.txt"
sed -n "/^== 'InnerInt'/,\$p" "$O/disasm.txt" > "$O/innerint_dis.txt"
sed -n "/^== 'OuterInt'/,/^== 'InnerInt'/p" "$O/disasm.txt" > "$O/outerint_dis.txt"
expect "emitted private InnerRec has the tag test"    "$O/emitted.erl" "^'InnerRec'\(O\) when map_get\('Kind', O\) =:= 'Scope.Order'"
expect "beam private InnerRec has Kind test"          "$O/innerrec_dis.txt" "is_eq_exact.*Scope.Order"
absent "emitted private InnerInt has NO is_integer"   <(grep -A2 "^'InnerInt'" "$O/emitted.erl" | grep -v spec) "is_integer"
expect "emitted exported OuterInt has is_integer"     "$O/emitted.erl" "^'OuterInt'\(N\) when is_integer\(N\)"
expect "source line 284 reads 'none when Public' (int kind exported-only)" "$O/lines.txt" "^ *284.*none when Public"
expect "source line 276-277: tag branch has no Public condition"          "$O/lines.txt" "^ *277.*\{ok, Tag\} ->"
echo "p01 FAILS=$FAILS"; exit $FAILS

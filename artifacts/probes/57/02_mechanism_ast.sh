#!/usr/bin/env bash
# 02 -- the ticket's MECHANISM claim: "unary minus over an expression desugars
# to {e_op,'-',{e_int,0},E}", so `value >= -5` reaches the checker as
# {e_op,'>=',{e_var,value},{e_op,'-',{e_int,0},{e_int,5}}}.
# REFUTES the claim: the parsed refinement containing an `e_neg` node (or
# anything other than an e_op '-' over e_int 0). Parsing is done by the REPO's
# built bs_lexer/bs_parser beams, no patch involved.
. "$(dirname "$0")/lib.sh"
cat > "$OUT/ast.escript" <<'ES'
#!/usr/bin/env escript
main([Ebin, Src]) ->
  code:add_patha(Ebin),
  {ok, B} = file:read_file(Src),
  {ok, T, _} = bs_lexer:string(binary_to_list(B)),
  {ok, Decls} = bs_parser:parse(T),
  [io:format("~p~n", [P]) || {type_refined, _, _, _, P} <- Decls].
ES
mkdir -p "$OUT/ast"
for pair in 'neg5|value >= -5' 'dneg|value >= --5' 'parenneg|value >= -(5)' 'sub|value >= 2 + 3' 'subzero|value >= 0 - 5' 'negneg|value >= - -5' 'negvar|value >= -n'; do
  n=${pair%%|*}; p=${pair#*|}
  printf 'module M\ntype T = int where %s\n' "$p" > "$OUT/ast/$n.bs"
  echo "## $p" ; escript "$OUT/ast.escript" "$(ebin_of repo)" "$OUT/ast/$n.bs" 2>&1 | tee "$OUT/ast/$n.out"
done
grep -q "e_op,.*'-'" "$OUT/ast/neg5.out" && grep -q "{e_int,[^}]*,0}" "$OUT/ast/neg5.out" && got=desugared || got=not-desugared
expect "ticket: -5 parses to 0 - 5" desugared $got
grep -q 'e_neg' "$OUT/ast/neg5.out" && got=e_neg || got=other
expect "observed node for -5 is e_neg" e_neg $got
echo "# parser.yrl lines cited by the brief:"
grep -n "^expr_low -> '-' expr_low\|^negate(" "$REPO/compiler/src/bs_parser.yrl"

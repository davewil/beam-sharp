#!/usr/bin/env bash
# ast-shape.sh  — the AST a refinement comparand reaches the checker as, per variant, plus
# its size in words (erts_debug:flat_size) and the parse+check cost per compile.
# Run build-variant.sh for base/optA1/optB first.
set -uo pipefail
WORK=${WORK:-/tmp/p57work}
for v in base optA1 optA2 optB optC; do
  echo "== $v"
  erl -noshell -pa "$WORK/$v/ebin" -eval '
    Src = "module A\ntype T = int where value >= -5\npublic int Id(T b)\nId(b) -> b\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    case catch bs_parser:parse(Toks) of
      {ok, Forms} ->
        [begin io:format("  comparand AST : ~w~n  flat_size     : ~w words~n", [P, erts_debug:flat_size(P)]) end
         || {type_refined, _, _, _, P} <- lists:flatten([Forms])],
        io:format("  (whole module AST: ~w words)~n", [erts_debug:flat_size(Forms)]);
      Other -> io:format("  parse: ~p~n", [Other])
    end, halt().' 2>&1 | head -8
done

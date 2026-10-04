#!/bin/sh
# Compiler delta, part 1 (parser): prototype the spellings on a COPY of the real grammar and
# let yecc count conflicts; parse samples with the real lexer. Nothing under compiler/ changes.
. "$(dirname "$0")/env.sh"
here=$(cd "$(dirname "$0")" && pwd)
C=/home/user/beam-sharp/compiler
rm -rf $W/proto && mkdir -p $W/proto/base $W/proto/a $W/proto/b $W/proto/bk
for d in base a b bk; do cp $C/src/bs_parser.yrl $C/src/bs_lexer.xrl $W/proto/$d/; done
python3 $here/10_patch.py $W/proto || exit 1
cat > $W/proto/build.escript <<'E'
#!/usr/bin/env escript
main([Dir]) ->
    {Us, R} = timer:tc(fun() -> yecc:file(Dir ++ "/bs_parser.yrl", [verbose, {report, true}]) end),
    io:format("  yecc: ~p in ~.1f ms~n", [element(1, R), Us / 1000]),
    {ok, _} = leex:file(Dir ++ "/bs_lexer.xrl"),
    {ok, _} = compile:file(Dir ++ "/bs_parser.erl", [{outdir, Dir}, nowarn_unused_function]),
    {ok, _} = compile:file(Dir ++ "/bs_lexer.erl", [{outdir, Dir}]).
E
for d in base a b bk; do
  echo "== grammar variant: $d"
  escript $W/proto/build.escript $W/proto/$d > $W/proto/$d.log 2>&1
  grep -c "Conflict resolved in favor of" $W/proto/$d.log | sed "s|^|  conflicts resolved by yecc default (shift or reduce): |"
  grep "yecc:\|rror" $W/proto/$d.log
done
cat > $W/proto/parse.escript <<'E'
#!/usr/bin/env escript
main([Dir, File]) ->
    true = code:add_patha(Dir),
    {ok, Bin} = file:read_file(File),
    case bs_lexer:string(binary_to_list(Bin)) of
        {ok, Toks, _} ->
            case bs_parser:parse(Toks) of
                {ok, Ds} -> [io:format("    ~p~n", [strip(D)]) || D <- Ds, element(1, D) /= signature, element(1, D) /= module];
                E -> io:format("    parse error: ~p~n", [E])
            end;
        E -> io:format("    lex error: ~p~n", [E])
    end.
strip({foreign, L, M, Sigs}) -> {foreign, L, M, {sigs, length(Sigs)}};
strip({foreign, L, M, Sigs, A}) -> {foreign, L, M, {sigs, length(Sigs)}, A};
strip(D) -> D.
E
cat > $W/proto/a.bs <<'B'
module Net

using :'Elixir.Req' from :req {
    term new(list<(atom, term)> opts)
}
using :'Elixir.Req.Request' from :req {
    term get_header(term r, binary name)
}
using :lists {
    int sum(list<int> xs)
}
B
cat > $W/proto/b.bs <<'B'
module Net

requires :req
requires :jason

using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
B
echo "== A parses a.bs (per block)";   escript $W/proto/parse.escript $W/proto/a $W/proto/a.bs
echo "== A rejects a wrong word";       sed 's/ from :req/ by :req/' $W/proto/a.bs > $W/proto/a2.bs; escript $W/proto/parse.escript $W/proto/a $W/proto/a2.bs
echo "== B (contextual word) parses b.bs";  escript $W/proto/parse.escript $W/proto/b $W/proto/b.bs
echo "== B (keyword) parses b.bs";          escript $W/proto/parse.escript $W/proto/bk $W/proto/b.bs
echo "== B contextual: an unknown lowercase-word declaration"; printf 'module N\nrequire :x\n' > $W/proto/b3.bs; escript $W/proto/parse.escript $W/proto/b $W/proto/b3.bs
echo "== identifiers a reserved keyword would steal, over every .bs in the repo (real lexer)"
cat > $W/proto/count.escript <<'E'
#!/usr/bin/env escript
main([Root]) ->
    true = code:add_patha("/home/user/beam-sharp/compiler/_build/default/lib/bsc/ebin"),
    Files = filelib:wildcard(Root ++ "/**/*.bs"),
    Words = [from, requires, app, requires_app],
    Counts = lists:foldl(fun(F, Acc) ->
        {ok, Bin} = file:read_file(F),
        case bs_lexer:string(binary_to_list(Bin)) of
            {ok, Toks, _} -> lists:foldl(fun({lident, _, W}, A) -> case lists:member(W, Words) of true -> maps:update_with(W, fun(N) -> N + 1 end, 1, A); false -> A end; (_, A) -> A end, Acc, Toks);
            _ -> Acc end end, #{}, Files),
    io:format("  .bs files lexed: ~p; identifier counts: ~p~n", [length(Files), Counts]).
E
escript $W/proto/count.escript /home/user/beam-sharp

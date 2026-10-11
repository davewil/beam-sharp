#!/usr/bin/env bash
# Probe (e): how many PRIVATE functions in the shipped corpus (compiler/examples) carry a record
# tag test today, and how many private functions have a declared int/float parameter
# (would receive a kind test if the int rule widened)?  Run: ./probe_e_corpus.sh
cd "$(dirname "$0")"
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
W=${W:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/59/variants}
EX=/home/user/beam-sharp/compiler/examples
T=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/59
cat > $T/census.escript <<'ES'
#!/usr/bin/env escript
%% usage: census.escript BaseDir WidenDir NotagDir  -- compares per-module private guard counts
main([Base, Widen, Notag]) ->
    Mods = [filename:basename(F, ".abstr") || F <- filelib:wildcard(Base ++ "/*.abstr")],
    Tot = lists:foldl(fun(M, {PT, PK, Fn, PF}) ->
        B = guards(Base ++ "/" ++ M ++ ".abstr"),
        W = guards(Widen ++ "/" ++ M ++ ".abstr"),
        N = guards(Notag ++ "/" ++ M ++ ".abstr"),
        PrivTag = length([x || {{N1,A1},priv,G} <- B, lists:member(map_get,G),
                         not lists:member(map_get, proplists:get_value({N1,A1}, [{K,G2}||{K,_,G2}<-N]))]),
        PrivKind = length([x || {K,priv,G} <- W, (lists:member(is_integer,G) orelse lists:member(is_float,G)),
                          not (lists:member(is_integer, g(K,B)) orelse lists:member(is_float, g(K,B)))]),
        io:format("  ~-12s functions=~-3w private=~-3w  private-with-tag-test=~-2w  private-that-would-gain-kind-test=~-2w~n",
                  [M, length(B), length([x||{_,priv,_}<-B]), PrivTag, PrivKind]),
        {PT+PrivTag, PK+PrivKind, Fn+length(B), PF+length([x||{_,priv,_}<-B])}
      end, {0,0,0,0}, Mods),
    io:format("TOTAL functions=~w private=~w private-tag-tests=~w private-kind-tests-if-widened=~w~n",
              [element(3,Tot), element(4,Tot), element(1,Tot), element(2,Tot)]).
g(K, L) -> case lists:keyfind(K, 1, [{K1,G}||{K1,_,G}<-L]) of {_,G} -> G; false -> [] end.
guards(F) ->
    {ok, Forms} = file:consult(F),
    Exp = lists:append([L || {attribute,_,export,L} <- Forms]),
    [{{N,A}, case lists:member({N,A},Exp) of true->pub; false->priv end,
      lists:usort(find([Gs || {clause,_,_,Gs,_} <- Cs]))}
     || {function,_,N,A,Cs} <- Forms, N =/= bs@type_atoms].
find({call,_,{remote,_,{atom,_,erlang},{atom,_,N}},_}) -> [N];
find(T) when is_tuple(T) -> find(tuple_to_list(T));
find(L) when is_list(L) -> lists:append([find(X) || X <- L]);
find(_) -> [].
ES
for d in $EX/*/; do
  m=$(basename $d)
  for v in base notag widen; do
    mkdir -p corpus_$v
    BSC_EBIN=$W/$v/ebin ./bsc.sh --src-root $EX -o corpus_$v $d >/dev/null 2>&1 || echo "  (skipped $m under $v: does not compile standalone)"
  done
done 2>&1 | sort | uniq -c
escript $T/census.escript corpus_base corpus_widen corpus_notag
echo
echo "positive control (src/Scope has 1 private record fn + 1 private int fn; the census must see both):"
mkdir -p ctl_b ctl_n ctl_w
for v in b:base n:notag w:widen; do BSC_EBIN=$W/${v##*:}/ebin ./bsc.sh --src-root src -o ctl_${v%%:*} src/Scope >/dev/null; done
escript $T/census.escript ctl_b ctl_w ctl_n

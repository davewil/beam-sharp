#!/usr/bin/env bash
# Probe 2: compile every module under compiler/examples with the scratch bsc, then list every public export name
# (the REAL names the alias rule would have to handle) and apply candidate derivation rules to them.
. "$(dirname "$0")/common.sh"; EB=$SCR/p2ebin; rm -rf $EB; mkdir -p $EB
cd $REPO/compiler
ok=0; bad=0
for d in $(find examples -name '*.bs' -printf '%h\n' | sort -u); do
  if bsc --src-root examples -o $EB $d >$SCR/p2.err 2>&1; then ok=$((ok+1)); else bad=$((bad+1)); echo "FAILED to compile (scratch build): $d: $(head -c 150 $SCR/p2.err | tr '\n' ' ')"; fi
done
echo "modules compiled: $ok  failed: $bad  beams: $(ls $EB/*.beam | wc -l)"
cat > $SCR/p2.erl <<'ERL'
-module(p2).
-export([main/1]).
%% Rules under test. R1 = naive: insert _ before every uppercase that is not first, downcase.
r1(A) -> L = atom_to_list(A), list_to_atom(lists:flatten(r1s(L, true))).
r1s([], _) -> [];
r1s([C|T], First) when C >= $A, C =< $Z -> [[$_ || not First], C + 32 | r1s(T, false)];
r1s([C|T], _) -> [C | r1s(T, false)].
%% R2 = word-boundary aware (acronym run stays together): HTTPServer -> http_server, GetXML -> get_xml, Totals2 -> totals2
r2(A) -> L = atom_to_list(A), list_to_atom(r2s(L, [], undefined)).
r2s([], Acc, _) -> lists:reverse(Acc);
r2s([C|T], Acc, Prev) ->
    Up = C >= $A andalso C =< $Z,
    Nxt = case T of [N|_] -> N; [] -> $\s end,
    NxtLow = Nxt >= $a andalso Nxt =< $z,
    PrevLow = Prev =/= undefined andalso ((Prev >= $a andalso Prev =< $z) orelse (Prev >= $0 andalso Prev =< $9)),
    PrevUp = Prev =/= undefined andalso (Prev >= $A andalso Prev =< $Z),
    Sep = Up andalso (PrevLow orelse (PrevUp andalso NxtLow)),
    Low = if Up -> C + 32; true -> C end,
    r2s(T, [Low | (if Sep -> [$_|Acc]; true -> Acc end)], C).
%% R3 = plain downcase of the first letter only (New -> new, HandleCall -> handleCall): not snake_case, but call-syntax-legal
r3([C|T]) when C >= $A, C =< $Z -> [C+32|T].
main(Dir) ->
    {ok, Fs} = file:list_dir(Dir),
    Mods = [list_to_atom(filename:rootname(F)) || F <- Fs, filename:extension(F) =:= ".beam"],
    All = lists:usort(lists:append([[{M, N, A} || {N, A} <- exports(M, Dir), not is_bs(N)] || M <- Mods])),
    io:format("public exports (excluding module_info, bs@ names): ~p across ~p modules~n", [length(All), length(Mods)]),
    Names = lists:usort([N || {_, N, _} <- All]),
    io:format("distinct names: ~p~n", [length(Names)]),
    io:format("~nname -> R1 / R2 (differences only):~n"),
    [io:format("  ~-22s R1=~-24s R2=~s~n", [N, r1(N), r2(N)]) || N <- Names, r1(N) =/= r2(N)],
    io:format("~nR1 collisions across (module, arity):~n"),
    Groups = lists:foldl(fun({M,N,A}, Acc) -> maps:update_with({M, r1(N), A}, fun(L) -> [N|L] end, [N], Acc) end, #{}, All),
    Coll = [{K, V} || {K, V} <- maps:to_list(Groups), length(V) > 1],
    io:format("  ~p~n", [Coll]),
    io:format("~nnames whose alias is an auto-imported BIF (erl_internal:bif/2) at same arity, R1:~n"),
    [io:format("  ~s/~p in ~s -> ~s (BIF)~n", [N, A, M, r1(N)]) || {M, N, A} <- All, erl_internal:bif(r1(N), A)],
    io:format("~nnames whose R1 alias is an Elixir/Erlang reserved word:~n"),
    Res = ['after','and','andalso','band','begin','bnot','bor','bsl','bsr','bxor','case','catch','cond','div','end','fun','if','let','not','of','or','orelse','receive','rem','try','when','xor', 'do','else','fn','in','nil','true','false','rescue'],
    [io:format("  ~s -> ~s~n", [N, r1(N)]) || N <- Names, lists:member(r1(N), Res)],
    io:format("~nnames whose R1 alias already exists as an export of the same module/arity:~n"),
    [io:format("  ~p~n", [{M,N,A}]) || {M,N,A} <- All, lists:member({M, r1(N), A}, All), r1(N) =/= N],
    io:format("~nnames containing digits or underscore (R1/R2 ambiguity):~n"),
    [io:format("  ~s R1=~s R2=~s~n", [N, r1(N), r2(N)]) || N <- Names, lists:any(fun(C) -> (C >= $0 andalso C =< $9) orelse C =:= $_ end, atom_to_list(N))],
    io:format("~nsample all names (R1): ~p~n", [[{N, r1(N)} || N <- lists:sublist(Names, 400)]]).
exports(M, Dir) -> {ok, {M, [{exports, E}]}} = beam_lib:chunks(filename:join(Dir, atom_to_list(M) ++ ".beam"), [exports]), [X || X = {N, _} <- E, N =/= module_info].
is_bs(N) -> lists:prefix("bs@", atom_to_list(N)).
ERL
(cd $SCR && erlc p2.erl) && erl -noshell -pa $SCR -eval "p2:main(\"$EB\"), halt()."

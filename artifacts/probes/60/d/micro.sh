#!/usr/bin/env bash
# 60/d micro: the predicate's own cost. NOTE: this times a VERBATIM COPY of visible_to/3 + parent/1 + in_subtree/2
# from proto/ticket60.patch (the originals are not exported). 1e6 calls, 9 repeats.
cat > /tmp/bs60_micro.erl <<'EOF'
-module(bs60_micro).
-export([main/0]).
visible_to(Self, M, World) ->
    Entry = maps:get(M, World, #{}),
    Internal = maps:get(internal, Entry, false),
    Friends = maps:get(friends, Entry, []),
    case {Internal, Friends} of
        {false, []} -> true;
        _ -> (Internal andalso in_subtree(Self, parent(M))) orelse lists:member(Self, Friends)
    end.
parent(M) -> case string:split(atom_to_list(M), ".", trailing) of [P, _] -> list_to_atom(P); _ -> none end.
in_subtree(_Self, none) -> true;
in_subtree(Self, P) -> S = atom_to_list(Self), Ps = atom_to_list(P), S =:= Ps orelse lists:prefix(Ps ++ ".", S).
main() ->
    W = #{'App.M3' => #{internal => true, friends => []}, 'App.M4' => #{}},
    Run = fun(M) -> lists:sort([begin {T,_} = timer:tc(fun() -> loop(1000000, M, W) end), T end || _ <- lists:seq(1,9)]) end,
    [begin Ts = Run(M), io:format("~p: min=~p ns/call median=~p ns/call~n", [M, lists:nth(1,Ts)/1000, lists:nth(5,Ts)/1000]) end
     || M <- ['App.M4', 'App.M3']].
loop(0,_,_) -> ok;
loop(N,M,W) -> visible_to('App.Z.Deep', M, W), loop(N-1,M,W).
EOF
cd /tmp && erlc bs60_micro.erl && erl -noshell -pa /tmp -eval 'bs60_micro:main(), halt().'

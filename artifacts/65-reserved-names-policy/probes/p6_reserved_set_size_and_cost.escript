#!/usr/bin/env escript
-mode(compile).
%% Probe (measure): (a) size of the reserved set TODAY, extracted from compiler/src/bs_check.erl by parsing the
%% source with epp/erl_scan (not hard-coded); (b) cost of the reserved-name check against N reserved names over a
%% 1000-module tree, three implementations; (c) a correctness cross-check so the probe can FAIL: the hit count from
%% each implementation must equal an independently computed count.
%% Run: escript p6_reserved_set_size_and_cost.escript /home/user/beam-sharp/compiler/src/bs_check.erl
main([Src]) ->
    {ok, Bin} = file:read_file(Src),
    {ok, Toks, _} = erl_scan:string(binary_to_list(Bin)),
    Forms = split_forms(Toks, [], []),
    Quals = eval_fun0(Forms, reserved_qualifiers, Forms),
    Std   = eval_fun0(Forms, standard_table, Forms),
    Protos = protocol_names(Forms),
    Rows = length(Std),
    ByQ = lists:foldl(fun({{Q,_,_},_}, M) -> maps:update_with(Q, fun(X)->X+1 end, 1, M) end, #{}, Std),
    io:format("reserved qualifiers (bs_check:reserved_qualifiers/0): ~p  (~p)~n", [length(Quals), Quals]),
    io:format("protocol names also refused as module names (protocol_table keys): ~p~n", [Protos]),
    io:format("standard_table rows: ~p  by qualifier: ~p~n", [Rows, lists:sort(maps:to_list(ByQ))]),
    io:format("distinct bare module names refused today: ~p~n~n", [length(lists:usort(Quals ++ Protos))]),
    %% --- cost ---
    Tree = [mod_name(I) || I <- lists:seq(1, 1000)],           % 1000 modules, dotted, 1-4 segments
    Planted = [list_to_atom("Shop.Mod" ++ integer_to_list(I)) || I <- lists:seq(1,3)],
    io:format("tree: ~p modules, distinct ~p, whole-name collisions with a name of the real set: ~p~n",
              [length(Tree), length(lists:usort(Tree)), length([M || M <- Tree, lists:member(M, Quals)])]),
    lists:foreach(fun(N) -> bench(N, Quals, Tree ++ [hd(Quals)|Planted]) end, [4, 16, 100, 1000, 10000]).

bench(N, Real, Tree) ->
    Reserved = Real ++ [list_to_atom("Reserved" ++ integer_to_list(I)) || I <- lists:seq(length(Real)+1, N)],
    Reps = 200,
    Truth = length([M || M <- Tree, lists:member(M, Reserved)]),       % independent oracle: naive comprehension
    {TL, HL} = rep(Reps, fun() -> length([M || M <- Tree, lists:member(M, Reserved)]) end),  % what bs_check does per module
    Map = maps:from_keys(Reserved, true),
    {TM, HM} = rep(Reps, fun() -> length([M || M <- Tree, is_map_key(M, Map)]) end),
    Set = sets:from_list(Reserved, [{version, 2}]),
    {TS, HS} = rep(Reps, fun() -> length([M || M <- Tree, sets:is_element(M, Set)]) end),
    case lists:usort([Truth, HL, HM, HS]) of
        [_] -> ok;
        Other -> io:format("MISMATCH hit counts ~p~n", [Other]), halt(2)
    end,
    io:format("N=~6w reserved | per 1000-module tree: lists:member ~8.1f us | map ~8.1f us | sets ~8.1f us | hits ~p~n",
              [N, TL/Reps, TM/Reps, TS/Reps, Truth]).

rep(Reps, F) ->
    {T, R} = timer:tc(fun() -> lists:last([F() || _ <- lists:seq(1, Reps)]) end),
    {T, R}.

mod_name(I) ->
    Segs = ["Shop","Billing","Orders","Text","Collections","Net","Mail","Util"],
    Depth = 1 + (I rem 4),
    S = lists:join(".", [lists:nth(1 + ((I*K) rem 8), Segs) || K <- lists:seq(1, Depth)] ++ ["M" ++ integer_to_list(I)]),
    list_to_atom(lists:flatten(S)).

split_forms([], Cur, Acc) -> lists:reverse(Acc) ++ [lists:reverse(Cur) || Cur =/= []];
split_forms([{dot,_}=D|T], Cur, Acc) -> split_forms(T, [], [lists:reverse([D|Cur])|Acc]);
split_forms([H|T], Cur, Acc) -> split_forms(T, [H|Cur], Acc).

eval_fun0(_Forms0, Name, Forms) ->
    [Toks] = [F || F <- Forms, [{atom,_,N},{'(',_},{')',_},{'->',_}|_] <- [F], N =:= Name],
    {ok, [E]} = erl_parse:parse_exprs(tl(tl(tl(tl(Toks))))),
    %% local calls (declared_rows/0) are resolved by evaluating that function from the same source
    LFH = fun(F, []) -> eval_fun0(x, F, Forms) end,
    {value, V, _} = erl_eval:expr(E, [], {value, LFH}), V.

protocol_names(Forms) ->
    %% keys of the map literal returned by protocol_table/0: atoms immediately followed by '=>' at nesting depth 1
    [Toks] = [F || F <- Forms, [{atom,_,protocol_table},{'(',_},{')',_},{'->',_}|_] <- [F]],
    [A || {{atom,_,A},{'=>',_}} <- lists:zip(Toks, tl(Toks) ++ [{dot,0}])].

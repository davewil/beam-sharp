#!/usr/bin/env escript
%% Run: escript p4_subtree_check_prototype.escript [N]   (default sizes 100,1000,10000 when no arg)
%% Prototype of the two places a "may this module name that one" check could sit:
%%   EDGE  : once per `using` edge, at add_import/add_module_import time (bs_check.erl:497-509 analogue)
%%   SITE  : once per remote call site, walking the Erlang abstract forms the emitter would produce
%% World: module path atoms 'Shop.G3.M12'. Some modules carry internal_to = <path prefix>.
%% Ground truth is an independent token-list prefix implementation (tok_prefix/2); the two binary-based
%% checkers must reproduce it exactly, including a negative control: 'Shopify.X' must NOT count as inside 'Shop'.
main([]) -> [run(N) || N <- [100, 1000, 10000]];
main([A]) -> run(list_to_integer(A)).

run(N) ->
    rand:seed(exsss, {1, 2, 3}),
    G = max(2, N div 20),
    %% modules: "Shop.G<g>.M<i>" ; every group has "Shop.G<g>.Core" internal_to "Shop.G<g>"
    Cores = [{path(["Shop", "G" ++ integer_to_list(X), "Core"]), path(["Shop", "G" ++ integer_to_list(X)])} || X <- lists:seq(0, G-1)],
    Plain = [path(["Shop", "G" ++ integer_to_list(X), "M" ++ integer_to_list(I)]) || X <- lists:seq(0, G-1), I <- lists:seq(1, N div G)],
    %% negative control: sibling-prefix module `ShopX.G0.Spy` sharing the *string* prefix "Shop" with group "Shop"
    Spy = path(["ShopX", "G0", "Spy"]),
    InternalTo = maps:from_list([{'Shop.Top', 'Shop'} | Cores]),
    Callers = [Spy | Plain],
    Edges = lists:foldl(fun(Caller, Acc) ->
        %% each caller uses its own group's Core (legal), and with prob 1/10 another group's Core (violation), plus 4 plain modules
        Own = own_core(Caller, Cores),
        Other = element(1, lists:nth(rand:uniform(G), Cores)),
        Targets = [Own || Caller =/= Spy] ++ [Other || rand:uniform(10) =:= 1 andalso Caller =/= Spy] ++ ['Shop.Top' || Caller =:= Spy]
                  ++ [lists:nth(rand:uniform(length(Plain)), Plain) || _ <- [1,2,3,4]],
        Acc#{Caller => lists:usort(Targets)}
    end, #{}, Callers),
    %% ground truth (generator side, independent): token-list prefix test
    Truth = lists:sort([{C, T} || {C, Ts} <- maps:to_list(Edges), T <- Ts,
                         maps:is_key(T, InternalTo), not tok_prefix(maps:get(T, InternalTo), C)]),
    %% EDGE check
    {TE, EdgeViol} = timer:tc(fun() ->
        lists:sort([{C, T} || {C, Ts} <- maps:to_list(Edges), T <- Ts,
                    case InternalTo of #{T := P} -> not bin_inside(P, C); _ -> false end]) end),
    %% SITE check: build abstract forms, 40 remote calls per module over its using-edges
    Forms = maps:map(fun(C, Ts) ->
        Calls = [{call, 1, {remote, 1, {atom, 1, lists:nth((K rem length(Ts)) + 1, Ts)}, {atom, 1, f}}, []} || K <- lists:seq(1, 40)],
        [{attribute, 1, module, C}, {function, 1, g, 0, [{clause, 1, [], [], Calls}]}]
    end, Edges),
    {TS, SiteViol} = timer:tc(fun() ->
        lists:usort(lists:append([ [{C, T} || T <- calls_of(Fs), case InternalTo of #{T := P} -> not bin_inside(P, C); _ -> false end]
                        || {C, Fs} <- maps:to_list(Forms)])) end),
    %% mutant: naive string-prefix test (no segment boundary) must DISAGREE with truth on the Spy
    NaiveViol = lists:sort([{C, T} || {C, Ts} <- maps:to_list(Edges), T <- Ts,
                    case InternalTo of #{T := P} -> not lists:prefix(atom_to_list(P), atom_to_list(C)); _ -> false end]),
    SpyFlagged = lists:member({Spy, 'Shop.Top'}, EdgeViol),
    io:format("N=~p modules, ~p edges, ~p planted-or-random violations~n", [length(Callers), lists:sum([length(T) || T <- maps:values(Edges)]), length(Truth)]),
    io:format("  EDGE check ~.2f ms (matches truth: ~p)~n", [TE/1000, EdgeViol =:= Truth]),
    io:format("  SITE check ~.2f ms over ~p call sites (matches truth: ~p)~n", [TS/1000, length(Callers) * 40, SiteViol =:= Truth]),
    io:format("  negative control ShopX.G0.Spy -> Shop.Top (internal_to Shop) flagged (must be true): ~p~n", [SpyFlagged]),
    io:format("  mutant naive-string-prefix agrees with truth (must be false: ShopX and Shop.G10-vs-Shop.G1 escape it): ~p~n", [NaiveViol =:= Truth]),
    case {EdgeViol =:= Truth, SiteViol =:= Truth, SpyFlagged, NaiveViol =:= Truth} of
        {true, true, true, false} -> ok;
        _ -> io:format("FAIL~n"), halt(1)
    end.

path(Segs) -> list_to_atom(lists:flatten(lists:join(".", Segs))).
own_core(C, Cores) ->
    Segs = string:split(atom_to_list(C), ".", all),
    case Segs of
        ["Shop", Gr | _] -> path(["Shop", Gr, "Core"]);
        _ -> element(1, hd(Cores))
    end,
    case Segs of ["Shop", Gr2 | _] -> path(["Shop", Gr2, "Core"]); _ -> element(1, hd(Cores)) end.
tok_prefix(P, C) -> lists:prefix(string:split(atom_to_list(P), ".", all), string:split(atom_to_list(C), ".", all)).
%% production-style: binary match on segment boundary
bin_inside(P, C) ->
    PB = atom_to_binary(P), CB = atom_to_binary(C), S = byte_size(PB),
    CB =:= PB orelse (byte_size(CB) > S andalso binary:part(CB, 0, S) =:= PB andalso binary:at(CB, S) =:= $.).
calls_of(Forms) -> lists:append([walk(F) || F <- Forms]).
walk({call, _, {remote, _, {atom, _, M}, _}, As}) -> [M | lists:append([walk(A) || A <- As])];
walk(T) when is_tuple(T) -> lists:append([walk(E) || E <- tuple_to_list(T)]);
walk(L) when is_list(L) -> lists:append([walk(E) || E <- L]);
walk(_) -> [].

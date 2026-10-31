#!/usr/bin/env escript
%% Run: escript p2_xref_caller_restriction.escript [N]    (N modules, default 200)
%% Question: OTP xref can answer "who calls module X" post hoc. What does a subtree restriction
%% cost as an xref query over N compiled modules, and is it wired into compilation? (erlc: no.)
%% Tree: shop_g<K>_m<I>; module "shop_g0_core" is internal to group g0 (callers named shop_g0_*).
%% Planted violations are recorded by the generator; the query result is compared to them.
main(Args) ->
    N = case Args of [A|_] -> list_to_integer(A); _ -> 200 end,
    Dir = filename:join(os:getenv("TMPDIR","/tmp"), "p2_" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    Groups = max(1, N div 10),
    Internal = [list_to_atom("shop_g" ++ integer_to_list(G) ++ "_core") || G <- lists:seq(0, Groups-1)],
    Mods = [{G, I} || G <- lists:seq(0, Groups-1), I <- lists:seq(1, N div Groups)],
    {Planted, _} = lists:foldl(fun({G, I}, {Acc, Seed}) ->
        Name = list_to_atom("shop_g" ++ integer_to_list(G) ++ "_m" ++ integer_to_list(I)),
        %% every 7th module also illegally calls the NEXT group's internal core
        Viol = (I rem 7 =:= 0) andalso Groups > 1,
        Other = lists:nth(((G + 1) rem Groups) + 1, Internal),
        Own = lists:nth(G + 1, Internal),
        Body = "f() -> " ++ atom_to_list(Own) ++ ":h()" ++
               [", " ++ atom_to_list(Other) ++ ":h()" || Viol] ++ ".\n",
        ok = file:write_file(filename:join(Dir, atom_to_list(Name) ++ ".erl"),
            "-module(" ++ atom_to_list(Name) ++ ").\n-export([f/0]).\n" ++ Body),
        {[{Name, Other} || Viol] ++ Acc, Seed}
    end, {[], 0}, Mods),
    [ok = file:write_file(filename:join(Dir, atom_to_list(C) ++ ".erl"),
        "-module(" ++ atom_to_list(C) ++ ").\n-export([h/0]).\nh() -> ok.\n") || C <- Internal],
    {CT, _} = timer:tc(fun() -> [{ok, _} = compile:file(F, [{outdir, Dir}, debug_info]) || F <- filelib:wildcard(Dir ++ "/*.erl")] end),
    {ok, _} = xref:start(s), 
    ok = xref:set_default(s, [{verbose,false},{warnings,false}]),
    {XT1, _} = timer:tc(fun() -> {ok, _} = xref:add_directory(s, Dir) end),
    %% module-level call edges, restricted to callee modules in Internal
    {XT2, {ok, Edges}} = timer:tc(fun() -> xref:q(s, "ME") end),
    Viol = [{F, T} || {F, T} <- Edges, lists:member(T, Internal), not same_group(F, T)],
    Expected = lists:sort(Planted),
    Found = lists:sort(Viol),
    io:format("N=~p modules (+~p internal cores); erlc total ~.1f ms~n", [N, Groups, CT/1000]),
    io:format("xref add_directory ~.1f ms; query ME ~.1f ms; edges=~p~n", [XT1/1000, XT2/1000, length(Edges)]),
    io:format("planted violations=~p, found by xref+subtree filter=~p, equal=~p~n",
              [length(Expected), length(Found), Expected =:= Found]),
    %% pure xref expression variant: calls INTO core modules from everything, native query language
    {XT3, {ok, Q}} = timer:tc(fun() -> xref:q(s, "ME || (Mod) shop_g0_core") end),
    io:format("native-language restriction (ME || (Mod) shop_g0_core, callee-restricted) returned ~p edges in ~.1f ms (callers of one core)~n", [length(Q), XT3/1000]),
    xref:stop(s),
    case Expected =:= Found of true -> ok; false -> io:format("FAIL: mismatch~n"), halt(1) end.
same_group(F, T) ->
    P = fun(M) -> hd(string:split(atom_to_list(M), "_", all) -- [""]) end, 
    G = fun(M) -> [_, Gr | _] = string:split(atom_to_list(M), "_", all), Gr end,
    _ = P, G(F) =:= G(T).

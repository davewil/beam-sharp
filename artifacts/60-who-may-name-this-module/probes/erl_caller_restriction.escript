#!/usr/bin/env escript
%% PREDICTION (written before running):
%%  1. -export is all-or-nothing: `outsider` (unrelated module) calls the exported
%%     shop_orders:recompute_total/1 successfully; no attribute limits callers.
%%  2. -nifs([nif_like/0]) on a non-NIF and -on_load do not restrict callers (nif_like/0 still returns
%%     not_a_nif to anyone; on_load merely runs init/0). -compile({inline,..}) likewise.
%%  3. xref (analysis after compile) reports outsider -> shop_orders:recompute_total/1 as a caller edge,
%%     i.e. 'who calls whom' is computable but nothing enforces it. Small fixture: expect < 50 ms.
%% NOTE: first draft used xref operator | (edges OUT of the module) instead of || (edges INTO it); a query-syntax
%% slip of mine, fixed before any conclusion; the prediction was not changed.
main(_) ->
    Dir = "fixtures/erl", Out = "/tmp/b60_ebin",
    os:cmd("rm -rf " ++ Out), ok = filelib:ensure_dir(Out ++ "/x"),
    lists:foreach(fun(F) -> {ok,_} = compile:file(F, [{outdir,Out},debug_info]) end,
                  filelib:wildcard(Dir ++ "/*.erl")),
    true = code:add_patha(Out),
    io:format("1. outsider:go() = ~p~n", [outsider:go()]),
    io:format("1b. shop_reports:go() = ~p~n", [shop_reports:go()]),
    io:format("2. shop_orders:module_info(exports) = ~p~n", [lists:sort(shop_orders:module_info(exports))]),
    io:format("2b. shop_orders:nif_like() = ~p (declared -nifs)~n", [shop_orders:nif_like()]),
    io:format("2c. on_load ran: ~p~n", [shop_orders:loaded()]),
    io:format("2d. attributes = ~p~n", [[A || {K,_}=A <- shop_orders:module_info(attributes), K=/=vsn]]),
    {ok,_} = xref:start(s), 
    {T, _} = timer:tc(fun() -> xref:set_default(s,[{verbose,false},{warnings,false}]), {ok,_}=xref:add_directory(s, Out) end),
    {T2, {ok, Q}} = timer:tc(fun() -> xref:q(s, "E || shop_orders : Mod") end),
    io:format("3. xref add_directory ~p us; query ~p us~n", [T, T2]),
    io:format("3b. edges INTO shop_orders: ~p~n", [lists:sort(Q)]),
    {ok, Callers} = xref:q(s, "(Fun) (E || shop_orders:recompute_total/1)"),
    io:format("3c. callers of recompute_total/1: ~p~n", [lists:sort(Callers)]),
    xref:stop(s),
    %% scale: generate 300 modules each calling its predecessor, time xref
    Big = "/tmp/b60_big", os:cmd("rm -rf " ++ Big), ok = filelib:ensure_dir(Big ++ "/x"),
    [begin Src = io_lib:format("-module(m~p).~n-export([f/0]).~nf() -> m~p:f().~n", [I, I-1]),
           F = Big ++ "/m" ++ integer_to_list(I) ++ ".erl", ok = file:write_file(F, Src),
           {ok,_} = compile:file(F, [{outdir,Big},debug_info,report_errors]) end || I <- lists:seq(1,300)],
    ok = file:write_file(Big ++ "/m0.erl", "-module(m0).\n-export([f/0]).\nf() -> ok.\n"),
    {ok,_} = compile:file(Big ++ "/m0.erl", [{outdir,Big}]),
    {ok,_} = xref:start(b),
    {T3, _} = timer:tc(fun() -> {ok,_} = xref:add_directory(b, Big) end),
    {T4, {ok,Q4}} = timer:tc(fun() -> xref:q(b, "E || m0 : Mod") end),
    io:format("4. 301 modules: xref add_directory ~p us; callers-of-m0 query ~p us -> ~p~n", [T3, T4, Q4]),
    xref:stop(b).

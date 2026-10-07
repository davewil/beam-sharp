#!/usr/bin/env escript
%% Measurements for ticket 52. usage: measure.escript ABSTR_FILE FIXTURE_ROOT
%% 1. cost of carrying provenance in the .beam (attribute shapes), 2. cost of a compile-time presence check,
%% 3. whether app name/version are derivable from the code path alone.
main([Abstr, Fix]) ->
    {ok, Forms0} = file:consult(Abstr),
    Fm = fun(Extra) ->
        [M | Rest] = Forms0,
        [M | Extra] ++ Rest
    end,
    Variants = [
      {"none",                    []},
      {"app name only (1 app)",   [{attribute,0,bs_requires,[req]}]},
      {"app+vsn (1 app)",         [{attribute,0,bs_requires,[{req,"0.7.3"}]}]},
      {"3 apps, names only",      [{attribute,0,bs_requires,[req,jason,finch]}]},
      {"per-block: 3 attrs",      [{attribute,0,bs_requires,req},{attribute,0,bs_requires,jason},{attribute,0,bs_requires,finch}]}
    ],
    io:format("~n[1] beam size with a provenance attribute (Up.abstr, compile:forms [debug_info,binary])~n"),
    Base = size_of(Fm([])),
    [begin
        {ok,_,Bin} = compile:forms(Fm(E), [debug_info,binary,return_errors]),
        {ok,{_,[{attributes,A}]}} = beam_lib:chunks(Bin,[attributes]),
        io:format("  ~-26s beam=~5b B  delta=~3b B  Attr chunk reads back: ~p~n",
                  [N, byte_size(Bin), byte_size(Bin)-Base, [X || {bs_requires,_}=X <- A]])
     end || {N,E} <- Variants],
    io:format("~n[2] cost of a compile-time presence check (median of 5 batches x 2000 calls, microseconds/call)~n"),
    ErlLibs = [filename:join(Fix,"otp_style"), filename:join(Fix,"mix_style")],
    [code:add_pathz(P) || L <- ErlLibs, P <- filelib:wildcard(filename:join([L,"*","ebin"]))],
    T = fun(F) ->
        L = lists:sort([begin
              {US,_} = timer:tc(fun() -> [F() || _ <- lists:seq(1,2000)] end), US/2000 end || _ <- lists:seq(1,5)]),
        {lists:nth(1,L), lists:nth(3,L), lists:nth(5,L)}
    end,
    io:format("  code:which(module) present   (min,med,max): ~p~n", [T(fun() -> code:which('Elixir.Req') end)]),
    io:format("  code:which(module) absent    (min,med,max): ~p~n", [T(fun() -> code:which('Elixir.NoSuch') end)]),
    io:format("  code:lib_dir(app) present    (min,med,max): ~p~n", [T(fun() -> code:lib_dir(req) end)]),
    io:format("  code:lib_dir(app) absent     (min,med,max): ~p~n", [T(fun() -> code:lib_dir(nosuch) end)]),
    io:format("  for scale: compile:forms of the same module, one call: ~p us~n",
              [element(1, timer:tc(fun() -> compile:forms(Fm([]), [debug_info,binary]) end))]),
    io:format("~n[3] what the code path itself says (no source declaration)~n"),
    io:format("  code:which('Elixir.Req')   = ~p~n", [code:which('Elixir.Req')]),
    io:format("  code:lib_dir(req)          = ~p~n", [code:lib_dir(req)]),
    io:format("  application:get_application('Elixir.Req') before app loaded = ~p~n", [application:get_application('Elixir.Req')]),
    {ok, [{application, req, Props}]} = file:consult(filename:join([code:lib_dir(req), "ebin", "req.app"])),
    io:format("  vsn from req.app           = ~p ; applications = ~p~n", [proplists:get_value(vsn,Props), proplists:get_value(applications,Props)]),
    %% [4] a per-block declaration lets the compiler also check module-in-app (a module-level list cannot)
    In = fun(M, App) ->
        W = code:which(M), D = code:lib_dir(App),
        is_list(W) andalso is_list(D) andalso lists:prefix(D, W)
    end,
    io:format("~n[4] module-belongs-to-declared-app check (code:which prefix of code:lib_dir)~n"),
    io:format("  'Elixir.Req' in req   = ~p~n  'Elixir.Req' in jason = ~p (jason not on path -> lib_dir error)~n  lists in stdlib = ~p ; lists in kernel = ~p~n",
              [In('Elixir.Req', req), In('Elixir.Req', jason), In(lists, stdlib), In(lists, kernel)]),
    {US4,_} = timer:tc(fun() -> [In('Elixir.Req', req) || _ <- lists:seq(1,2000)] end),
    io:format("  cost of the combined check: ~.1f us/call~n", [US4/2000]),
    ok.

size_of(F) -> {ok,_,B} = compile:forms(F, [debug_info,binary]), byte_size(B).

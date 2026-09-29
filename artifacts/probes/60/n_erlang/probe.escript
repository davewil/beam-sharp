#!/usr/bin/env escript
%% EXPECTED (stated before the run; see brief §2, probes N1-N3):
%%  N1. erlc (with +debug_info) of lib_a, shop_b, vendor_c: all three compile, no warning about
%%      shop_b's call to the unexported lib_a:priv/0 nor about shop_b's use of the unexported
%%      remote type lib_a:privt() (remote references are not checked at compile time).
%%  N2. b:go_pub() = 1 ; shop_b:go_priv() dies with undef (run time only).
%%  N3. xref: undefined_function_calls = exactly [shop_b:go_priv/0 -> lib_a:priv/0];
%%      "XC | (Mod)vendor_c || (Mod)lib_a" lists exactly vendor_c's edge into lib_a: a who-calls-whom
%%      POLICY is a query someone runs after the build; xref has no declaration that forbids an edge.
main(_) ->
    Dir = filename:dirname(escript:script_name()), Out = "/tmp/claude-0/p60erl",
    os:cmd("rm -rf " ++ Out ++ "; mkdir -p " ++ Out),
    R = [compile:file(filename:join(Dir, F), [debug_info, return, {outdir, Out}])
         || F <- ["lib_a.erl", "shop_b.erl", "vendor_c.erl"]],
    Warn = [{M, W} || {ok, M, W} <- R],
    io:format("N1 compile results: ~p~n", [Warn]),
    N1 = (proplists:get_value(shop_b, Warn) =:= []) andalso (proplists:get_value(vendor_c, Warn) =:= []),
    code:add_patha(Out),
    Pub = shop_b:go_pub(), Priv = catch shop_b:go_priv(),
    io:format("N2 go_pub=~p go_priv=~p~n", [Pub, element(1, element(2, Priv))]),
    N2 = Pub =:= 1 andalso element(1, element(2, Priv)) =:= undef,
    {ok, _} = xref:start(s), xref:set_default(s, [{verbose, false}, {warnings, false}]),
    {ok, _} = xref:add_directory(s, Out),
    {ok, U} = xref:analyze(s, undefined_function_calls),
    {ok, E} = xref:q(s, "XC | (Mod)vendor_c || (Mod)lib_a"),
    io:format("N3 undefined_function_calls=~p~nN3 edges vendor_c->lib_a=~p~n", [U, E]),
    N3 = U =:= [{{shop_b,go_priv,0},{lib_a,priv,0}}] andalso E =:= [{{vendor_c,go,0},{lib_a,pub,0}}],
    xref:stop(s),
    [io:format("~s ~s~n", [case B of true -> "PASS"; false -> "FAIL" end, N]) || {N, B} <- [{"N1",N1},{"N2",N2},{"N3",N3}]],
    halt(case N1 andalso N2 andalso N3 of true -> 0; false -> 1 end).

#!/usr/bin/env escript
%% usage: p9_beam_size.escript <Module.abstr>
%% Measures what recording an application list COSTS in the .beam, by editing the abstract forms bsc emitted and compiling with
%% bsc's own options ([from_abstr -> forms, debug_info]). N=3 compiles per variant, all must give the same byte_size.
main([Abstr]) ->
    {ok, Forms0} = file:consult(Abstr),
    Apps = [req, finch, mint, jason, mime, nimble_options, nimble_pool, telemetry, hpax, ssl, inets, plug],
    Base = size_of(Forms0),
    io:format("baseline (stock forms, recompiled)         : ~p bytes~n", [Base]),
    {ok, M, Bin0, _} = compile_forms(Forms0),
    io:format("   module ~p; chunks: ~s~n", [M, chunks(Bin0)]),
    %% what the existing per-module metadata function costs, as a yardstick: remove bs@type_atoms/0
    NoTA = [F || F <- Forms0, not is_type_atoms(F)],
    NoTA2 = [fix_export(F) || F <- NoTA],
    io:format("yardstick: removing existing bs@type_atoms/0 saves ~p bytes (this is the F55 per-module metadata function)~n",
              [Base - size_of(NoTA2)]),
    lists:foreach(fun(K) ->
        As = lists:sublist(Apps, K),
        A = size_of(add_attr(Forms0, bs_needs, As)),
        F = size_of(add_fun(Forms0, As)),
        V = size_of(add_attr(Forms0, bs_needs, [{X, "0.7.3"} || X <- As])),
        io:format("~2w app(s): attribute -bs_needs([..])  +~4w   function 'bs@needs'/0 +~4w   attribute WITH a version string each +~4w~n",
                  [K, A - Base, F - Base, V - Base])
    end, [1, 3, 9, 12]),
    %% per-`using` repetition: one attribute per foreign block (3 blocks, same app)
    Per = lists:foldl(fun(_, Fs) -> add_attr(Fs, bs_foreign, [{'Elixir.Req', req}]) end, Forms0, [1,2,3]),
    io:format("per-block provenance, 3 blocks x {Mod,App}   : +~p bytes~n", [size_of(Per) - Base]),
    %% determinism control
    Ss = [size_of(add_attr(Forms0, bs_needs, [req])) || _ <- [1,2,3]],
    io:format("determinism control (3 compiles, 1 app attribute): ~p -> ~s~n", [Ss, case lists:usort(Ss) of [_] -> "stable"; _ -> "UNSTABLE" end]),
    %% the attribute is readable by tools
    {ok, Bin} = compile_bin(add_attr(Forms0, bs_needs, [req, jason])),
    {ok, {_, [{attributes, At}]}} = beam_lib:chunks(Bin, [attributes]),
    io:format("beam_lib:chunks(Bin,[attributes]) -> bs_needs = ~p~n", [proplists:get_value(bs_needs, At)]).

is_type_atoms({function,_,'bs@type_atoms',0,_}) -> true; is_type_atoms(_) -> false.
fix_export({attribute,L,export,Es}) -> {attribute,L,export,[E || E <- Es, E =/= {'bs@type_atoms',0}]}; fix_export(F) -> F.
add_attr([{attribute,L,module,_}=M | R], Name, Val) -> [M, {attribute,L,Name,Val} | R].
add_fun(Forms, Apps) ->
    Forms1 = [case F of {attribute,L,export,Es} -> {attribute,L,export,[{'bs@needs',0}|Es]}; _ -> F end || F <- Forms],
    Forms1 ++ [{function,0,'bs@needs',0,[{clause,0,[],[],[erl_parse:abstract(Apps)]}]}].
compile_forms(Forms) -> case compile:forms(Forms, [debug_info, binary, return_errors]) of {ok, M, B} -> {ok, M, B, []}; E -> E end.
compile_bin(Forms) -> {ok, _, B, _} = compile_forms(Forms), {ok, B}.
size_of(Forms) -> {ok, B} = compile_bin(Forms), byte_size(B).
chunks(Bin) -> {ok, _, Cs} = beam_lib:all_chunks(Bin),
    string:join([io_lib:format("~s=~p", [Id, byte_size(D)]) || {Id, D} <- Cs], " ").

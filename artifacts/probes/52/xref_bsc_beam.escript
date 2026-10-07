#!/usr/bin/env escript
%% Does stock xref already see a B# beam's missing foreign module? (bsc compiles with debug_info.)
%% usage: xref_bsc_beam.escript BEAMDIR [ERL_LIBS-style library root ...]
main([Dir | Libs]) ->
    code:add_path(Dir),
    %% xref reads Elixir beams' debug_info through the elixir_erl backend, so Elixir's ebin must be loadable
    [[code:add_pathz(E) || E <- filelib:wildcard(filename:join([L, "*", "ebin"]))] || L <- Libs],
    {ok,_} = xref:start(s), xref:set_default(s,[{warnings,false}]),
    {ok,_} = xref:add_directory(s, Dir),
    [begin {ok,_} = xref:add_release(s, L, {name, lib}) end || L <- Libs],
    {ok, U} = xref:analyze(s, undefined_function_calls),
    Mine = [list_to_atom(filename:basename(F, ".beam")) || F <- filelib:wildcard(filename:join(Dir, "*.beam"))],
    io:format("undefined_function_calls from ~p: ~p~n", [Mine, [X || {{M,_,_},_}=X <- U, lists:member(M, Mine)]]).

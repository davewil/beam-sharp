#!/usr/bin/env escript
%% usage: friend.escript EbinDir ; a caller-side "who may name this module" pass over beam files via xref.
%% Rule (MODEL): module a_b_internal may be called only from modules whose name starts with a_b_ minus "_internal" prefix.
main([Dir]) ->
    {ok, _} = xref:start(s),
    xref:set_default(s, [{verbose,false},{warnings,false}]),
    {ok, _} = xref:add_directory(s, Dir),
    {ok, Calls} = xref:q(s, "ME"),   %% module-to-module call edges
    {ok, Undef} = xref:analyze(s, undefined_function_calls),
    io:format("module edges: ~p~n", [Calls]),
    io:format("undefined_function_calls: ~p~n", [Undef]),
    Bad = [{From, To} || {From, To} <- Calls, not allowed(From, To)],
    io:format("friend violations: ~p~n", [Bad]).
allowed(From, To) ->
    case lists:suffix("_internal", atom_to_list(To)) of
        false -> true;
        true ->
            Pre = lists:sublist(atom_to_list(To), length(atom_to_list(To)) - length("_internal")),
            lists:prefix(Pre, atom_to_list(From))
    end.

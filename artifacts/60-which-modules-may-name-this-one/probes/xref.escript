#!/usr/bin/env escript
%% P5: OTP xref sees the cross-module call graph of B# output with no compiler change.
%% usage: xref.escript BeamDir CalleeModule AllowedCallerPrefix
main([Dir, Callee, Prefix]) ->
    {ok, _} = xref:start(s), xref:set_default(s, [{warnings, false}]),
    {ok, _} = xref:add_directory(s, Dir),
    {ok, Es} = xref:q(s, "E"),
    C = list_to_atom(Callee),
    Cross = [{CM, CF, CA, FM, FF, FA} || {{CM, CF, CA}, {FM, FF, FA}} <- Es, FM =:= C, CM =/= C],
    io:format("all call edges: ~p~ncross-module edges into ~s: ~p~n", [length(Es), Callee, Cross]),
    Viol = [E || {CM, _, _, _, _, _} = E <- Cross, not lists:prefix(Prefix, atom_to_list(CM))],
    io:format("callers outside prefix ~p: ~p~n", [Prefix, Viol]).

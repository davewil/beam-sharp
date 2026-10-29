#!/usr/bin/env escript
-mode(compile).
%% recompiles the abstract code stored in a2/sh_remote.beam (B# emission shape: erlang:rem remote calls) with +inline
main([]) ->
    {ok, {_, [{abstract_code, {_, Forms0}}]}} = beam_lib:chunks("../a2/sh_remote.beam", [abstract_code]),
    Forms = [case F of {attribute, L, module, _} -> {attribute, L, module, sh_remote_inl}; _ -> F end || F <- Forms0],
    {ok, M, Bin} = compile:forms(Forms, [debug_info, inline, return_errors]),
    ok = file:write_file("sh_remote_inl.beam", Bin), io:format("wrote ~p~n", [M]).

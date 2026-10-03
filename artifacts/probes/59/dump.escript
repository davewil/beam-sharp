#!/usr/bin/env escript
%% usage: dump.escript FILE.beam [abstr|asm] [Fun ...]
main([File, Mode | Funs]) ->
    Want = [list_to_atom(F) || F <- Funs],
    case Mode of
        "abstr" ->
            {ok, {_, [{abstract_code, {_, Forms}}]}} = beam_lib:chunks(File, [abstract_code]),
            [io:format("~s~n", [erl_pp:function(F)])
             || F = {function, _, N, _, _} <- Forms, Want =:= [] orelse lists:member(N, Want)];
        "asm" ->
            {beam_file, _, _, _, _, Fs} = beam_disasm:file(File),
            [begin io:format("function ~p/~p~n", [N, A]),
                   [io:format("    ~p~n", [I]) || I <- Is], io:nl() end
             || {function, N, A, _, Is} <- Fs, Want =:= [] orelse lists:member(N, Want)]
    end.

#!/usr/bin/env escript
-mode(compile).
%% Reproduces bsc's build path (bsc.erl:845: compile:file(Abstr,[from_abstr,debug_info,{outdir,..}]); bs_emit.erl:2970 to_abstr
%% writes "%% coding: latin-1\n" ++ ~p. per form) for the sh_guard stand-in, then compares with compile:forms of the same forms.
main([]) ->
    {ok, {_, [{abstract_code, {_, Forms0}}]}} = beam_lib:chunks("../a2/sh_guard.beam", [abstract_code]),
    Forms = [case F of {attribute, _, module, _} -> {attribute, 0, module, via_abstr}; _ -> F end || F <- Forms0],
    ok = file:write_file("via_abstr.abstr", iolist_to_binary(["%% coding: latin-1\n" | [io_lib:format("~p.~n", [F]) || F <- Forms]])),
    {ok, via_abstr} = compile:file("via_abstr.abstr", [from_abstr, debug_info, {outdir, "."}, report_errors, report_warnings]),
    {ok, M, Bin} = compile:forms(Forms, [debug_info]),
    ok = file:write_file("via_forms.beam", Bin), io:format("ok ~p~n", [M]).

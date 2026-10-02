#!/usr/bin/env escript
%% Re-creates bsc's build path (bsc.erl:833-846, bs_emit.erl:2501): parse an
%% .erl, force every annotation to line 0 (bs_emit ?A = 0), write the forms with ~p
%% as a latin-1 .abstr, compile:file(from_abstr, debug_info).  Usage: pipe.escript Src.erl OutDir
main([Src, Out]) ->
    {ok, Forms0} = epp:parse_file(Src, []),
    Forms = [erl_parse:map_anno(fun(_)->0 end, F) || F <- Forms0, element(1, F) =/= eof, element(1, F) =/= file],
    Mod = list_to_atom(filename:basename(Src, ".erl") ++ "_bsc"),
    Forms1 = [case F of {attribute,_,module,_} -> {attribute,0,module,Mod}; _ -> F end || F <- Forms],
    ok = filelib:ensure_dir(filename:join(Out, "x")),
    P = filename:join(Out, atom_to_list(Mod) ++ ".abstr"),
    ok = file:write_file(P, iolist_to_binary(["%% coding: latin-1\n" | [io_lib:format("~p.~n", [F]) || F <- Forms1]])),
    {ok, Mod} = compile:file(P, [from_abstr, debug_info, {outdir, Out}, report_errors, report_warnings, to_asm]),
    {ok, Mod} = compile:file(P, [from_abstr, debug_info, {outdir, Out}, report_errors, report_warnings]).

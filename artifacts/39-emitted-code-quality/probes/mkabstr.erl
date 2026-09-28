%%% mkabstr.erl -- turn an Erlang source variant into the artefact bsc hands to OTP: a `.abstr` file of
%%% `~p.` abstract forms, ALL annotations forced to line 0 (bs_emit.erl:21 `-define(A, 0)`), later built with
%%% compile:file(Abstr, [from_abstr, debug_info, ...]) exactly as bsc.erl:843 does.
%%% Purpose: rule in/out "the from_abstr + debug_info + line-0 build path itself drops {tr} annotations".
%%% Prediction: the resulting spin/4 and wrap/1 carry the SAME {tr,..} annotations as v_base.
%%% usage: erl -noshell -pa build -run mkabstr main Src Name OutDir  Macro...
-module(mkabstr).
-export([main/1]).
main([Src, Name, OutDir | Macros]) ->
    Defs = [{list_to_atom(M), true} || M <- Macros] ++ [{'MOD', list_to_atom(Name)}],
    {ok, Forms0} = epp:parse_file(Src, [{macros, Defs}]),
    Forms = [erl_parse:map_anno(fun(_) -> 0 end, F) || F <- Forms0, element(1, F) =/= eof, element(1, F) =/= file_marker_],
    Bin = iolist_to_binary(["%% coding: latin-1\n" | [io_lib:format("~p.~n", [F]) || F <- Forms]]),
    Path = filename:join(OutDir, Name ++ ".abstr"),
    ok = file:write_file(Path, Bin),
    {ok, _} = compile:file(Path, [from_abstr, debug_info, {outdir, OutDir}, report_errors, report_warnings]),
    {ok, _} = compile:file(Path, [from_abstr, debug_info, {outdir, OutDir}, to_asm, report_errors]),
    halt().

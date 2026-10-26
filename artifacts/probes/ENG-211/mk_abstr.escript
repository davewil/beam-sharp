#!/usr/bin/env escript
%% usage: mk_abstr.escript SRC.erl MODE OUTDIR
%% Round-trips a hand-written Erlang module through the SAME route bsc uses
%% (bsc.erl:843): forms -> .abstr text on disk -> compile:file(from_abstr, debug_info).
%% MODE: ident | zero_fn_line | bs_like | nodebug
main([Src, Mode, Out]) ->
    {ok, Forms0} = epp:parse_file(Src, []),
    Forms = [F || F <- Forms0, element(1, F) =/= eof],
    Forms1 = case Mode of
        "zero_fn_line" -> [case F of {function,_,N,A,C} -> {function,0,N,A,C}; _ -> F end || F <- Forms];
        "bs_like"      -> [case F of
                              {function,_,N,A,C} -> {function,0,N,A,C};
                              {attribute,_,K,V}  -> {attribute,0,K,V};
                              _ -> F end || F <- Forms];
        _              -> Forms
    end,
    Mod = list_to_atom(filename:basename(Src, ".erl")),
    Abstr = filename:join(Out, atom_to_list(Mod) ++ ".abstr"),
    ok = filelib:ensure_dir(Abstr),
    ok = file:write_file(Abstr, iolist_to_binary(["%% coding: latin-1\n" |
            [io_lib:format("~p.~n", [F]) || F <- Forms1]])),
    Opts0 = [from_abstr, {outdir, Out}, report_errors, report_warnings],
    Opts = case Mode of "nodebug" -> Opts0; _ -> [debug_info | Opts0] end,
    {ok, _} = compile:file(Abstr, Opts),
    {ok, _} = compile:file(Abstr, [from_abstr, 'S', {outdir, Out}] ++ [debug_info || Mode =/= "nodebug"]).

#!/usr/bin/env escript
%%! -pa EBIN_PLACEHOLDER
%% bsh.escript SRC.bs ModName 'ErlangExpr.' ['dump:Fn' ...]
%%   compile a one-file B# module with the reference compiler, load it, evaluate ErlangExpr
%%   (module is callable as ModName), and optionally pretty-print the emitted Erlang of Fn.
main([Src, Mod, ExprStr | Dumps]) ->
    Ebin = os:getenv("BSC_EBIN"),
    true = code:add_patha(Ebin),
    Tmp = os:cmd("mktemp -d") -- "\n",
    ModDir = filename:join(Tmp, Mod), ok = filelib:ensure_dir(ModDir ++ "/x"),
    {ok, _} = file:copy(Src, filename:join(ModDir, "a.bs")),
    Out = filename:join(Tmp, "out"), ok = filelib:ensure_dir(Out ++ "/x"),
    case bsc:file_to_dir(filename:join(ModDir, "a.bs"), Out) of
        {ok, _} -> ok;
        Err -> io:format("COMPILE REFUSED: ~p~n", [Err]), halt(2)
    end,
    true = code:add_patha(Out),
    M = list_to_atom(Mod), code:purge(M),
    {module, M} = code:load_abs(filename:join(Out, Mod)),
    [begin
         Fn = list_to_atom(lists:nthtail(5, D)),
         {ok, {_, [{abstract_code, {_, Forms}}]}} =
             beam_lib:chunks(filename:join(Out, Mod ++ ".beam"), [abstract_code]),
         [io:format("~s~n", [erl_pp:function(F)]) || F = {function, _, N, _, _} <- Forms, N =:= Fn]
     end || D = "dump:" ++ _ <- Dumps],
    {ok, Toks, _} = erl_scan:string(ExprStr),
    {ok, Es} = erl_parse:parse_exprs(Toks),
    R = try {value, V, _} = erl_eval:exprs(Es, []), {ok, V}
        catch C:E -> {C, E} end,
    io:format("~p~n", [R]),
    {ok, Beam} = file:read_file(filename:join(Out, Mod ++ ".beam")),
    io:format("beam bytes: ~p~n", [byte_size(Beam)]).

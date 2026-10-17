#!/usr/bin/env escript
%% usage: rec_noguard.escript REC.abstr OUTDIR
%% Same module, same structure, with the record Kind-tag clause guard removed
%% from WeightOf/WeightP and renamed 'RecNG': an A/B that changes ONLY the tag test.
main([Abstr, Out]) ->
    {ok, Forms} = file:consult(Abstr),
    F = [fix(X) || X <- Forms],
    Path = filename:join(Out, "RecNG.abstr"),
    ok = file:write_file(Path, [io_lib:format("~p.~n", [X]) || X <- F]),
    {ok, 'RecNG'} = compile:file(Path, [from_abstr, debug_info, {outdir, Out}]),
    {ok, 'RecNG'} = compile:file(Path, [from_abstr, 'S', {outdir, Out}]).
fix({attribute, L, module, _}) -> {attribute, L, module, 'RecNG'};
fix({function, L, N, 1, [{clause, CL, Ps, [[{op, _, '=:=', {call, _, {remote, _, _, {atom, _, map_get}}, [{atom, _, 'Kind'}, _]}, _}]], Body}]})
  when N =:= 'WeightOf'; N =:= 'WeightP' ->
    {function, L, N, 1, [{clause, CL, Ps, [], Body}]};
fix(X) -> X.

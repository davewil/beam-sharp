#!/usr/bin/env escript
%% PROBE 3c — what does a thin alias wrapper look like in stack traces and call tracing?
%% argv: ALIAS_N10_BEAM (built with BS_ALIAS=wrapper)
%%
%% EXPECTED (before run):
%%   T1 a crash raised inside GetItem5 but entered through get_item5 has a stacktrace whose first
%%      frame is 'GetItem5' and which contains NO frame for get_item5 (the wrapper is a tail call).
%%   T2 a call trace ({'N10','_','_'} local) of ONE call to get_item5(1) records TWO call events
%%      ('get_item5' then 'GetItem5'); of ONE call to 'GetItem5'(1), ONE.
%%   T3 a caller sees the alias name in trace/profiling output for calls it made by the alias
%%      name, so tooling (eprof/cprof/recon) counts every alias call twice.
main([Beam]) ->
    {ok, Bin} = file:read_file(Beam),
    {module, 'N10'} = code:load_binary('N10', Beam, Bin),
    St = try 'N10':get_item5(not_an_int) catch error:_:S -> [F || {_, F, _, _} <- S] end,
    io:format("stack via alias: first frames ~p~n", [lists:sublist(St, 3)]),
    T1 = hd(St) =:= 'GetItem5' andalso not lists:member(get_item5, St),
    Alias = trace_count(fun() -> 'N10':get_item5(1) end),
    Direct = trace_count(fun() -> 'N10':'GetItem5'(1) end),
    io:format("call events for one alias call ~p; for one direct call ~p~n", [Alias, Direct]),
    T2 = Alias =:= [get_item5, 'GetItem5'] andalso Direct =:= ['GetItem5'],
    [io:format("~s ~s~n", [K, case V of true -> "PASS"; false -> "FAIL" end]) || {K, V} <- [{"T1 stack hides alias", T1}, {"T2 two trace events", T2}]],
    io:format("~s p3c~n", [case T1 andalso T2 of true -> "PASS"; false -> "FAIL" end]).

trace_count(Fun) ->
    Self = self(),
    P = spawn(fun() -> receive go -> Fun(), Self ! done end end),
    erlang:trace_pattern({'N10', '_', '_'}, true, [local]),
    erlang:trace(P, true, [call]),
    P ! go,
    receive done -> ok end,
    erlang:trace_pattern({'N10', '_', '_'}, false, [local]),
    collect([]).
collect(Acc) ->
    receive {trace, _, call, {'N10', F, _}} -> collect([F | Acc])
    after 100 -> lists:reverse(Acc) end.

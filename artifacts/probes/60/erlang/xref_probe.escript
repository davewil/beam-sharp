#!/usr/bin/env escript
%% Compile with no diagnostics, then ask xref the "who may name me" question
%% as an external, closed-world query.
main([Dir]) ->
    {ok, _} = xref:start(s),
    xref:set_default(s, [{verbose, false}, {warnings, false}]),
    {ok, _} = xref:add_directory(s, Dir),
    {ok, Calls} = xref:q(s, "E || shop_orders:recompute/1"),
    io:format("callers of shop_orders:recompute/1 (xref):~n  ~p~n", [lists:sort(Calls)]),
    Outside = [C || {{M, _, _}, _} = C <- Calls, not lists:prefix("shop_", atom_to_list(M))],
    io:format("callers outside the shop_ prefix (a hand-written rule, not part of xref):~n  ~p~n", [Outside]),
    {ok, Unused} = xref:analyze(s, exports_not_used),
    io:format("exports_not_used (the only built-in export analysis):~n  ~p~n", [Unused]).

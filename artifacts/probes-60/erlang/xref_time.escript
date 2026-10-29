#!/usr/bin/env escript
%% usage: xref_time.escript Dir  -- time add_directory (load graph) and module-edge query + subtree check over real beams
main([Dir]) ->
    T0 = erlang:monotonic_time(microsecond),
    {ok, _} = xref:start(s), xref:set_default(s, [{verbose,false},{warnings,false}]),
    {ok, Ms} = xref:add_directory(s, Dir),
    T1 = erlang:monotonic_time(microsecond),
    {ok, Edges} = xref:q(s, "ME"),
    T2 = erlang:monotonic_time(microsecond),
    %% prefix-test every edge (the subtree rule's inner op)
    N = length(Edges), _ = [lists:prefix(atom_to_list(T), atom_to_list(F)) || {F,T} <- Edges],
    T3 = erlang:monotonic_time(microsecond),
    io:format("modules=~p module_edges=~p load_ms=~p query_ms=~p check_ms=~p~n",
      [length(Ms), N, (T1-T0) div 1000, (T2-T1) div 1000, (T3-T2) div 1000]).

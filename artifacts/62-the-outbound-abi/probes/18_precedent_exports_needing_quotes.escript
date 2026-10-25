#!/usr/bin/env escript
%% Probe 18: do other BEAM languages emit unquoted-callable aliases for the other side's benefit?
%% Counts, in the installed Elixir 1.20.4 stdlib, exports an Erlang caller must QUOTE ('valid?'/1, '+'/2 ...).
%% (v1 also counted 'unquoted twins'; that was misleading -- read!/read are different functions, not aliases -- dropped.)
main([Dir]) ->
    Beams = filelib:wildcard(Dir ++ "/Elixir.{Enum,String,Map,List,Keyword,Kernel,Integer,File,Path}.beam"),
    lists:foreach(fun(B) ->
        {ok, {M, _}} = beam_lib:chunks(B, []),
        code:load_abs(filename:rootname(B)),
        Ex = [F || {F, _} <- M:module_info(exports), F =/= module_info],
        Q = [F || F <- Ex, not plain(atom_to_list(F))],
        io:format("~-16s exports=~4w need-quotes-from-Erlang=~3w~n",
                  [M, length(Ex), length(Q)]) end, lists:sort(Beams)).
plain([C | R]) when C >= $a, C =< $z -> lists:all(fun(X) -> (X >= $a andalso X =< $z) orelse (X >= $0 andalso X =< $9) orelse X =:= $_ orelse (X >= $A andalso X =< $Z) end, R);
plain(_) -> false.
strip(S) -> [C || C <- S, C =/= $? , C =/= $!].

#!/usr/bin/env escript
%% usage: count_guards.escript DIR   -- over every *.abstr / *.beam in DIR (recursive)
main([Dir]) ->
    Abstrs = filelib:wildcard(filename:join(Dir, "**/*.abstr")),
    Walk = fun W(T, P) when is_tuple(T) -> (case P(T) of true -> 1; false -> 0 end) + lists:sum([W(E, P) || E <- tuple_to_list(T)]);
               W(L, P) when is_list(L) -> lists:sum([W(E, P) || E <- L]);
               W(_, _) -> 0 end,
    Tag = fun({op,_,'=:=',{call,_,{remote,_,{atom,_,erlang},{atom,_,map_get}},[{atom,_,'Kind'}|_]},_}) -> true; (_) -> false end,
    Int = fun({call,_,{remote,_,{atom,_,erlang},{atom,_,is_integer}},_}) -> true; (_) -> false end,
    Flt = fun({call,_,{remote,_,{atom,_,erlang},{atom,_,is_float}},_}) -> true; (_) -> false end,
    GuardsOf = fun(Fs) -> [G || {function,_,_,_,Cl} <- Fs, {clause,_,_,G,_} <- Cl] end,
    Tot = lists:foldl(fun(F, {T0,I0,F0}) ->
                {ok, Fs} = file:consult(F), G = GuardsOf(Fs),
                {T0+Walk(G,Tag), I0+Walk(G,Int), F0+Walk(G,Flt)} end, {0,0,0}, Abstrs),
    Code = lists:sum([begin {ok,{_,[{"Code",C}]}} = beam_lib:chunks(B, ["Code"]), byte_size(C) end
                      || B <- filelib:wildcard(filename:join(Dir, "**/*.beam"))]),
    {T, I, Fl} = Tot,
    io:format("modules=~p tag_tests=~p is_integer=~p is_float=~p code_bytes=~p~n", [length(Abstrs), T, I, Fl, Code]).

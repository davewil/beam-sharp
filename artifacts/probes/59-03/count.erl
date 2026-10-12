-module(count).
-export([main/1]).
%% For each .abstr in Dir: per function, exported?, has record tag test in any clause guard?
main([Dir]) ->
    {ok, Fs} = file:list_dir(Dir),
    Rows = lists:append([one(filename:join(Dir, F)) || F <- lists:sort(Fs), filename:extension(F) =:= ".abstr"]),
    Priv = [R || {_,_,priv,_,_} = R <- Rows],
    Pub  = [R || {_,_,pub,_,_} = R <- Rows],
    PrivTag = [R || {_,_,priv,tag,_} = R <- Rows],
    PubTag = [R || {_,_,pub,tag,_} = R <- Rows],
    io:format("modules=~p user functions: public=~p private=~p~n", [length(Fs) div 2, length(Pub), length(Priv)]),
    io:format("public with tag test=~p private with tag test=~p~n", [length(PubTag), length(PrivTag)]),
    [io:format("  private+tag: ~s:~s/~p~n", [M, N, A]) || {M,{N,A},_,_,_} <- PrivTag],
    PubInt = length([R || {_,_,pub,_,true} = R <- Rows]), PrivInt = length([R || {_,_,priv,_,true} = R <- Rows]),
    io:format("is_integer guard: public=~p private=~p~n", [PubInt, PrivInt]).
one(F) ->
    {ok, Forms} = file:consult(F),
    M = filename:basename(F, ".abstr"),
    Exp = lists:append([L || {attribute,_,export,L} <- Forms]),
    [ {M, {atom_to_list(N), A}, case lists:member({N,A}, Exp) of true -> pub; false -> priv end,
       case has(Cs, tag) of true -> tag; false -> none end, has(Cs, int)}
      || {function,_,N,A,Cs} <- Forms, N =/= 'bs@type_atoms', not is_helper(N) ].
is_helper(N) -> lists:prefix("bs@", atom_to_list(N)).
has(Cs, tag) -> lists:any(fun({clause,_,_,G,_}) -> contains(G, tag) end, Cs);
has(Cs, int) -> lists:any(fun({clause,_,_,G,_}) -> contains(G, int) end, Cs).
contains(T, tag) -> walk(T, fun({op,_,'=:=',{call,_,{remote,_,{atom,_,erlang},{atom,_,map_get}},[{atom,_,'Kind'},_]},{atom,_,_}}) -> true; (_) -> false end);
contains(T, int) -> walk(T, fun({call,_,{remote,_,{atom,_,erlang},{atom,_,is_integer}},_}) -> true; (_) -> false end).
walk(T, P) -> case P(T) of true -> true; false ->
    if is_tuple(T) -> walk(tuple_to_list(T), P);
       is_list(T) -> lists:any(fun(X) -> walk(X, P) end, T);
       true -> false end end.

#!/usr/bin/env escript
%% usage: measure.escript FILE.abstr ...
%% For each module: beam bytes as emitted vs with the record TAG test removed from
%% private (non-exported) functions only. Same options bsc uses (debug_info).
main(Files) ->
    Rows = [row(F) || F <- Files],
    io:format("~-28s ~7s ~7s ~7s ~7s ~6s~n",
              ["module","priv","tagged","bytes","stripped","delta"]),
    [io:format("~-28s ~7w ~7w ~7w ~7w ~6w~n", [M,P,T,B0,B1,B0-B1]) || {M,P,T,B0,B1} <- Rows],
    {_,P,T,B0,B1} = lists:foldl(fun({_,A,B,C,D},{_,A0,B0_,C0,D0}) -> {tot,A+A0,B+B0_,C+C0,D+D0} end,
                                {tot,0,0,0,0}, Rows),
    io:format("~-28s ~7w ~7w ~7w ~7w ~6w~n", ["TOTAL",P,T,B0,B1,B0-B1]).

row(F) ->
    {ok, Forms} = file:consult(F),
    [Mod] = [M || {attribute,_,module,M} <- Forms],
    Exports = lists:append([L || {attribute,_,export,L} <- Forms]),
    Priv = [Fn || {function,_,N,A,_}=Fn <- Forms, not lists:member({N,A},Exports)],
    {Forms1, Count} = strip(Forms, Exports),
    B0 = bytes(Forms), B1 = bytes(Forms1),
    {Mod, length(Priv), Count, B0, B1}.

bytes(Forms) ->
    {ok,_,Bin,_} = compile:forms(Forms, [debug_info, binary, return]),
    byte_size(Bin).

strip(Forms, Exports) ->
    lists:mapfoldl(fun({function,L,N,A,Cs}=Fn, Acc) ->
        case lists:member({N,A},Exports) of
            true -> {Fn, Acc};
            false ->
                {Cs1, K} = lists:mapfoldl(fun({clause,CL,Ps,Gs,B}, K0) ->
                     {Gs1, K1} = lists:mapfoldl(fun(G,KK) ->
                           G1 = [T || T <- G, not is_tag(T)],
                           {G1, KK + (length(G)-length(G1))} end, 0, Gs),
                     {{clause,CL,Ps,[G || G <- Gs1, G =/= []],B}, K0+min(1,K1)} end, 0, Cs),
                {{function,L,N,A,Cs1}, Acc+K};
            _ -> {Fn,Acc}
        end;
       (X, Acc) -> {X, Acc} end, 0, Forms).

is_tag({op,_,'=:=',{call,_,{remote,_,{atom,_,erlang},{atom,_,map_get}},[{atom,_,'Kind'},_]},{atom,_,_}}) -> true;
is_tag(_) -> false.

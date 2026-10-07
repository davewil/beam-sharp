#!/usr/bin/env escript
%% usage: bench.escript FILE.abstr  -- ns/call of Outer(o)->Inner(o) and OuterInt(n)->IInner(n)
%% as emitted vs private-tag-stripped vs private-int-widened. 7 runs x 5M calls each, median and range.
-mode(compile).
main([F]) ->
    {ok, Forms0} = file:consult(F),
    Exports = lists:append([L || {attribute,_,export,L} <- Forms0]),
    Vars = [{emitted, Forms0},
            {stripped, [strip(X, Exports) || X <- Forms0]},
            {widened, [widen(X, Exports, Forms0) || X <- Forms0]}],
    O = #{'Kind' => 'Guard.Order', 'Id' => 1, 'Total' => 7},
    [begin
        {ok, M, Bin, _} = compile:forms(Fs, [binary, return]),
        {module, M} = code:load_binary(M, "Guard.beam", Bin),
        R1 = runs(fun() -> loop_o(M, O, 5000000) end),
        R2 = runs(fun() -> loop_i(M, 5, 5000000) end),
        io:format("~-9s Outer->Inner(record): ~s    OuterInt->IInner(int): ~s~n", [V, fmt(R1), fmt(R2)]),
        code:purge(M), code:delete(M)
     end || {V, Fs} <- Vars].
runs(Fun) -> Fun(), lists:sort([begin {T,_} = timer:tc(Fun), T*1000/5000000 end || _ <- lists:seq(1,7)]).
fmt(L) -> io_lib:format("median ~.2f ns  [min ~.2f max ~.2f]", [lists:nth(4,L), hd(L), lists:last(L)]).
loop_o(_, _, 0) -> ok;
loop_o(M, O, N) -> M:'Outer'(O), loop_o(M, O, N-1).
loop_i(_, _, 0) -> ok;
loop_i(M, I, N) -> M:'OuterInt'(I), loop_i(M, I, N-1).
strip({function,L,N,A,Cs}, Exports) ->
    case lists:member({N,A},Exports) of
        true -> {function,L,N,A,Cs};
        false -> {function,L,N,A,[{clause,CL,Ps,[G1||G<-Gs,G1<-[[T||T<-G,not is_tag(T)]],G1=/=[]],B}||{clause,CL,Ps,Gs,B}<-Cs]}
    end;
strip(X,_) -> X.
is_tag({op,_,'=:=',{call,_,{remote,_,{atom,_,erlang},{atom,_,map_get}},[{atom,_,'Kind'},_]},{atom,_,_}}) -> true;
is_tag(_) -> false.
widen({function,L,N,A,Cs}, Exports, All) ->
    case lists:member({N,A},Exports) of
        true -> {function,L,N,A,Cs};
        false ->
            Spec = [Ts || {attribute,_,spec,{{N1,A1},[{type,_,'fun',[{type,_,product,Ts},_]}]}} <- All, N1 =:= N, A1 =:= A],
            Ints = case Spec of [Ts0] -> [I || {I,{type,_,integer,[]}} <- lists:zip(lists:seq(1,length(Ts0)),Ts0)]; _ -> [] end,
            Tests = [{call,0,{remote,0,{atom,0,erlang},{atom,0,is_integer}},[V]} || I <- Ints, {var,_,_}=V <- [lists:nth(I,hd([Ps||{clause,_,Ps,_,_}<-Cs]))]],
            {function,L,N,A,[{clause,CL,Ps,case Gs of [] when Tests=/=[] -> [Tests]; [] -> []; _ -> [Tests++G||G<-Gs] end,B}||{clause,CL,Ps,Gs,B}<-Cs]}
    end;
widen(X,_,_) -> X.

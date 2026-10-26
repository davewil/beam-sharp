#!/usr/bin/env escript
%% P5: APPROXIMATION, NOT bsc. Cost of parsing 10,000 guard clauses holding `-5`,
%% versus one extra checker-side constant-fold pass over the resulting forms
%% (fold `{op,-,{integer,N}}` and integer `+ - *` of two literals).
%% Both timings are Erlang's own erl_parse and a 12-line fold written for this
%% probe; they bound the order of magnitude and say nothing about bs_parser.yrl.
-mode(compile).
main(_) ->
    N = 10000,
    Src = lists:flatten([io_lib:format("f~w(X) when X >= -~w -> a.~n", [I, I rem 97 + 1]) || I <- lists:seq(1, N)]),
    Runs = 7,
    Parse = [begin {T, Fs} = timer:tc(fun() -> parse_all(Src) end), {T, Fs} end || _ <- lists:seq(1, Runs)],
    {_, Forms} = hd(Parse),
    Fold = [element(1, timer:tc(fun() -> [fold(F) || F <- Forms] end)) || _ <- lists:seq(1, Runs)],
    io:format("clauses=~w runs=~w~n", [N, Runs]),
    io:format("parse_us  min=~w median=~w~n", [lists:min([T || {T,_} <- Parse]), med([T || {T,_} <- Parse])]),
    io:format("fold_us   min=~w median=~w~n", [lists:min(Fold), med(Fold)]),
    %% control: after folding, no unary node remains
    Left = count(fun({op,_,'-',{integer,_,_}}) -> true; (_) -> false end, [fold(F) || F <- Forms]),
    Before = count(fun({op,_,'-',{integer,_,_}}) -> true; (_) -> false end, Forms),
    io:format("unary-minus-literal nodes: before=~w after=~w~n", [Before, Left]).
parse_all(Src) ->
    {ok, Ts, _} = erl_scan:string(Src, 1),
    Chunks = split(Ts, [], []),
    [begin {ok, F} = erl_parse:parse_form(C), F end || C <- Chunks].
split([], [], Acc) -> lists:reverse(Acc);
split([{dot,_}=D|T], Cur, Acc) -> split(T, [], [lists:reverse([D|Cur])|Acc]);
split([H|T], Cur, Acc) -> split(T, [H|Cur], Acc).
fold({op,L,'-',{integer,_,N}}) -> {integer,L,-N};
fold({op,L,Op,A,B}) ->
    case {fold(A), fold(B)} of
        {{integer,_,X},{integer,_,Y}} when Op=:='+' -> {integer,L,X+Y};
        {{integer,_,X},{integer,_,Y}} when Op=:='-' -> {integer,L,X-Y};
        {{integer,_,X},{integer,_,Y}} when Op=:='*' -> {integer,L,X*Y};
        {A1,B1} -> {op,L,Op,A1,B1}
    end;
fold(T) when is_tuple(T) -> list_to_tuple([fold(E) || E <- tuple_to_list(T)]);
fold(L) when is_list(L) -> [fold(E) || E <- L];
fold(X) -> X.
count(P, T) when is_tuple(T) -> (case P(T) of true -> 1; false -> 0 end) + count(P, tuple_to_list(T));
count(P, [H|T]) -> count(P, H) + count(P, T);
count(_, _) -> 0.
med(L) -> lists:nth((length(L)+1) div 2, lists:sort(L)).

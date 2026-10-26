#!/usr/bin/env escript
%% P6: does Erlang accept constant ARITHMETIC (not just `-5`) in a pattern, and a
%% variable in one? (erl_lint:is_pattern_expr/1 is the cited site.)
main(_) ->
    try_src("-module(m). -export([p/1]). p(2+3) -> a; p(-(1 bsl 2)) -> b; p(_) -> z."),
    try_src("-module(m). -export([p/1]). p(N) when N >= 2+3 -> a; p(_) -> z."),
    try_src("-module(m). -export([p/2]). p(X, 2+X) -> a; p(_, _) -> z.").
try_src(S) ->
    {ok, Ts, _} = erl_scan:string(S),
    Forms = split(Ts, [], []),
    Parsed = [begin {ok, F} = erl_parse:parse_form(T), F end || T <- Forms],
    case compile:forms(Parsed, [return_errors, binary]) of
        {ok, M, Bin} ->
            code:load_binary(M, "m.erl", Bin),
            R = [{I, catch M:p(I)} || I <- [5, -4, 7]] ,
            io:format("~s~n   compiled; calls ~w~n", [S, R]);
        {error, Es, _} -> io:format("~s~n   REFUSED ~p~n", [S, Es])
    end.
split([], [], Acc) -> lists:reverse(Acc);
split([{dot,_}=D|T], Cur, Acc) -> split(T, [], [lists:reverse([D|Cur])|Acc]);
split([H|T], Cur, Acc) -> split(T, [H|Cur], Acc).

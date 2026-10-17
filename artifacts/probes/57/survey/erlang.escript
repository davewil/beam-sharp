#!/usr/bin/env escript
%% Erlang/OTP: negative literal in pattern, in expression, and as a -type range bound.
main(_) ->
    P = fun(S) -> {ok, T, _} = erl_scan:string(S), {ok, F} = erl_parse:parse_form(T), F end,
    io:format("pattern   f(-5) -> ok.            ~p~n", [element(3, hd(element(5, P("f(-5) -> ok."))))]),
    io:format("expr      f() -> -5.              ~p~n", [element(5, hd(element(5, P("f() -> -5."))))]),
    io:format("guard     f(X) when X >= -5 -> X. ~p~n", [element(4, hd(element(5, P("f(X) when X >= -5 -> X."))))]),
    %% -type bound: the parser leaves {op,'-',..} and erl_lint folds it with erl_eval:partial_eval
    lists:foreach(fun(Bound) ->
        Src = "-module(m). -export_type([t/0]). -type t() :: " ++ Bound ++ ".",
        {ok, T, _} = erl_scan:string(Src), Forms = [begin {ok, F} = erl_parse:parse_form(X), F end || X <- split(T)],
        R = case compile:forms(Forms, [return_errors, export_all]) of
                {ok, _, _} -> "accepted"; {ok, _, _, _} -> "accepted"; {error, E, _} -> io_lib:format("refused ~p", [E]) end,
        io:format("-type t() :: ~-22s ~s~n", [Bound, R]) end,
      ["-5..5", "-(5)..5", "- -5..9", "(2+3)..10", "0-5..5", "2*-3..5", "(1 bsl 3)..10"]).
split(Ts) -> split(Ts, [], []).
split([], [], Acc) -> lists:reverse(Acc);
split([{dot,_}=D|R], Cur, Acc) -> split(R, [], [lists:reverse([D|Cur])|Acc]);
split([T|R], Cur, Acc) -> split(R, [T|Cur], Acc).

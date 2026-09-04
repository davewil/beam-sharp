-module(erlang_guard).
-export([classify/1, test/0]).

%% Does Erlang's guard machinery treat `-5` as a literal or as an operator
%% application over 5? Two probes:
%%  1. `X >= -5` in a real guard -- does it work at all (it should, since
%%     unary '-' over a literal is an OTP guard BIF).
%%  2. Parse tree inspection via erl_parse:parse_form/1 on a case guard
%%     `when X >= -5` to see the literal AST node Erlang's own grammar
%%     produces for `-5` in that exact position.
classify(X) when X >= -5 -> hi;
classify(_) -> lo.

test() ->
    hi = classify(-5),
    hi = classify(0),
    lo = classify(-6),
    io:format("classify/1 guard `X >= -5` works: hi(-5)=~p hi(0)=~p lo(-6)=~p~n",
               [classify(-5), classify(0), classify(-6)]),

    %% Now inspect what the PARSER actually produces for `-5` inside a guard.
    Src = "f(X) when X >= -5 -> ok.",
    {ok, Toks, _} = erl_scan:string(Src),
    {ok, Form} = erl_parse:parse_form(Toks),
    io:format("~n Parsed form for `f(X) when X >= -5 -> ok.`:~n  ~p~n", [Form]),
    halt().

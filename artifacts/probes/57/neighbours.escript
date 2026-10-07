#!/usr/bin/env escript
%% How Erlang parses/folds -5 (erl_parse), and whether guards fold arithmetic.
main(_) ->
    P = fun(S) -> {ok,T,_} = erl_scan:string(S), {ok,[E]} = erl_parse:parse_exprs(T), E end,
    [io:format("~-14s erl_parse -> ~p~n", [S, P(S)]) || S <- ["-5.","- 5.","-(-5).","0-5.","2+3.","-5.0."]],
    io:format("erl_eval -5 -> ~p~n", [element(2, erl_eval:expr(P("-5."), []))]),
    %% erl_lint accepts -5 and 2+3 in a guard, and a pattern `-5`?
    {ok,T1,_} = erl_scan:string("f(X) when X >= -5 -> a; f(X) when X >= 2+3 -> b."),
    {ok,F1} = erl_parse:parse_form(T1), io:format("guard AST: ~p~n", [F1]),
    {ok,T2,_} = erl_scan:string("f(-5) -> a; f(2+3) -> b."),
    {ok,F2} = erl_parse:parse_form(T2), io:format("pattern AST: ~p~n", [F2]),
    %% erl_lint on abstract with a literal negative integer node vs op node
    L = fun(Forms) -> erl_lint:module(Forms) end,
    Mod = [{attribute,1,module,m},{attribute,1,export,[{f,1}]},
           {function,1,f,1,[{clause,1,[{var,1,'X'}],[[{op,1,'>=',{var,1,'X'},{integer,1,-5}}]],[{atom,1,a}]}]}],
    io:format("lint with {integer,1,-5}: ~p~n", [element(1, L(Mod))]),
    ok.

#!/usr/bin/env escript
%%! -noshell
%% 57_erlang -- survey: how Erlang reads a negative literal. Claims: (1) erl_parse does NOT fold `-5`
%% (an {op,_,'-',{integer,_,5}} node, like B#'s e_neg); (2) the fold happens after parsing, in
%% erl_lint:is_pattern_expr (via erl_eval:partial_eval) and sys_core_fold; (3) a guard `X >= -5` is
%% accepted and a pattern `f(2+3)` is accepted, `f(N+1)` refused. REFUTED by: the parse output
%% showing {integer,_,-5}, or (3) rows differing.
main(_) ->
    P = fun(S) -> {ok, T, _} = erl_scan:string(S), {ok, E} = erl_parse:parse_exprs(T), E end,
    [io:format("parse ~-14s -> ~w~n", [S, strip(P(S))]) || S <- ["-5.", "- 5.", "-(-5).", "-5 + 10.", "-2 * 3.", "2 + 3."]],
    io:format("erl_eval:partial_eval(-5) = ~w ; (-(-5)) = ~w ; (2+3) = ~w ; (N+1) = ~w~n",
        [strip(erl_eval:partial_eval(hd(P("-5.")))), strip(erl_eval:partial_eval(hd(P("-(-5).")))),
         strip(erl_eval:partial_eval(hd(P("2+3.")))), strip(erl_eval:partial_eval(hd(P("N+1."))))]),
    Mod = fun(Body) -> "-module(m). -export([f/1]). " ++ Body end,
    Try = fun(Name, Body) ->
        {ok, T, _} = erl_scan:string(Mod(Body)),
        Forms = split(T),
        R = compile:noenv_forms([ F || {ok, F} <- [erl_parse:parse_form(X) || X <- Forms] ], [return, report_errors, to_core]),
        io:format("~-34s ~s~n", [Name, case R of {ok, _, Core, _} -> "accepted ; core guard/lit: " ++ core_snip(Core); {error, Es, _} -> "REFUSED " ++ lists:flatten(io_lib:format("~p", [Es])) end]) end,
    Try("guard  f(X) when X >= -5", "f(X) when X >= -5 -> a; f(_) -> b."),
    Try("guard  f(X) when X >= 2+3", "f(X) when X >= 2+3 -> a; f(_) -> b."),
    Try("guard  f(X) when X >= -(-5)", "f(X) when X >= -(-5) -> a; f(_) -> b."),
    Try("pattern f(-5)", "f(-5) -> a; f(_) -> b."),
    Try("pattern f(2+3)", "f(2+3) -> a; f(_) -> b."),
    Try("pattern f(-(-5))", "f(-(-5)) -> a; f(_) -> b."),
    Try("pattern f(-2*3)", "f(-2*3) -> a; f(_) -> b."),
    Try("pattern f(10 div 3)", "f(10 div 3) -> a; f(_) -> b."),
    Try("pattern f(N+1) (MUST refuse)", "f(N) -> case 1 of N+1 -> a; _ -> b end.").
split(Toks) -> split(Toks, [], []).
split([], [], Acc) -> lists:reverse(Acc);
split([{dot,_}=D | R], Cur, Acc) -> split(R, [], [lists:reverse([D|Cur]) | Acc]);
split([T | R], Cur, Acc) -> split(R, [T|Cur], Acc).
core_snip(Core) ->
    S = lists:flatten(core_pp:format(Core)),
    case re:run(S, "(-5|5|'>='|call [^\\n]*)", [global, {capture, first, list}]) of
        {match, Ms} -> lists:flatten(lists:join(" ", [M || [M] <- lists:sublist(Ms, 3)])); _ -> "?" end.
strip({L, _}) when is_integer(L) -> l;
strip(L) when is_integer(L), false -> l;
strip(T) when is_tuple(T), tuple_size(T) > 1, is_integer(element(2, T)), element(1,T) =/= integer -> list_to_tuple([element(1,T), l | [strip(X) || X <- tl(tl(tuple_to_list(T)))]]);
strip(T) when is_tuple(T) -> list_to_tuple([strip(X) || X <- tuple_to_list(T)]);
strip(L) when is_list(L) -> [strip(X) || X <- L];
strip(X) -> X.

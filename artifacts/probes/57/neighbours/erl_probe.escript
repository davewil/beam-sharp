#!/usr/bin/env escript
%% Real erl_scan/erl_parse/erl_lint/compile on `-5` in a pattern, a guard, and
%% an expression. REFUTES "Erlang keeps -5 uniform in the parser and folds
%% later": a parse result containing {integer,_,-5} for the unfolded forms.
main([]) ->
  Src = "-module(m57).\n-export([f/1,g/1,h/1,k/1]).\n"
        "f(-5) -> a.\n"
        "g(X) when X >= -5 -> a; g(_) -> b.\n"
        "h(X) -> X - -5.\n"
        "k(X) when X >= 2 + 3 -> a; k(_) -> b.\n",
  {ok, Toks, _} = erl_scan:string(Src),
  Forms = parse(Toks, []),
  [io:format("PARSE ~p~n", [F]) || {function,_,_,_,_} = F <- Forms],
  io:format("LINT  ~p~n", [erl_lint:module(Forms)]),
  {ok, m57, Core} = compile:forms(Forms, [to_core, binary, return_errors]),
  {ok, m57, Pre} = compile:forms(Forms, [to_core, no_copt, binary, return_errors]),
  io:format("PRE-OPT CORE (before sys_core_fold)~n~s~n", [core_pp:format(Pre)]),
  io:format("CORE~n~s~n", [core_pp:format(Core)]).
parse([], Acc) -> lists:reverse(Acc);
parse(Toks, Acc) ->
  {Form, Rest} = split(Toks, []),
  {ok, F} = erl_parse:parse_form(Form),
  parse(Rest, [F|Acc]).
split([{dot,_}=D|T], Acc) -> {lists:reverse([D|Acc]), T};
split([H|T], Acc) -> split(T, [H|Acc]).

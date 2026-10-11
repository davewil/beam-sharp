#!/usr/bin/env bash
# Erlang: how are -5, - 5, -(5), -(-5) parsed in an expression, a pattern, a guard, and a type range?
S=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad
source $S/env.sh
erl -noshell -eval '
P = fun(Src) -> {ok,T,_} = erl_scan:string(Src), case erl_parse:parse_exprs(T) of {ok,[E]} -> E; {error,R} -> {error,R} end end,
Show = fun(Tag, Src) -> io:format("~-34s ~-28s => ~p~n", [Tag, Src, P(Src)]) end,
[Show("expr", S) || S <- ["-5.","- 5.","-(5).","-(-5).","0-5.","-0."]],
%% pattern position: parse a fun clause and pull the pattern out
Pat = fun(Src) -> {ok,T,_} = erl_scan:string("fun(" ++ Src ++ ") -> ok end."), {ok,[{'"'"'fun'"'"',_,{clauses,[{clause,_,[Pt],_,_}]}}]} = erl_parse:parse_exprs(T), Pt end,
[io:format("~-34s ~-28s => ~p~n", ["pattern", S, Pat(S)]) || S <- ["-5","-(5)","- 5"]],
Grd = fun(Src) -> {ok,T,_} = erl_scan:string("fun(X) when " ++ Src ++ " -> ok end."), {ok,[{'"'"'fun'"'"',_,{clauses,[{clause,_,_,[[G]],_}]}}]} = erl_parse:parse_exprs(T), G end,
[io:format("~-34s ~-28s => ~p~n", ["guard", S, Grd(S)]) || S <- ["X >= -5","X >= 0-5"]],
%% type range: parse a -type
Ty = fun(Src) -> {ok,T,_} = erl_scan:string(Src), {ok,F} = erl_parse:parse_form(T), F end,
io:format("~-34s ~p~n", ["type -5..5", Ty("-type t() :: -5..5.")]),
%% where is the fold done?  erl_lint accepts patterns/ranges via erl_eval:partial_eval
io:format("partial_eval({op,1,-,{integer,1,5}}) = ~p~n", [erl_eval:partial_eval({op,1,'"'"'-'"'"',{integer,1,5}})]),
io:format("partial_eval(2+3)                  = ~p~n", [erl_eval:partial_eval({op,1,'"'"'+'"'"',{integer,1,2},{integer,1,3}})]),
%% full compile: negative literal in pattern, guard, and range type all accepted
Src = "-module(m). -export([f/1]). -type r() :: -5..5. -spec f(r()) -> atom(). f(-5) -> a; f(X) when X >= -(2+3) -> b; f(_) -> c.",
{ok,T2,_} = erl_scan:string(Src), Forms = [begin {ok,F2} = erl_parse:parse_form(Tk), F2 end || Tk <- (fun Split([]) -> []; Split(L) -> {A,[D|R]} = lists:splitwith(fun(X)-> element(1,X)=/=dot end, L), [A++[D]|Split(R)] end)(T2)],
io:format("compile:forms -> ~p~n", [element(1, compile:forms(Forms, [return]))]),
%% NEGATIVE CONTROL: a non-constant range bound must be refused by the same lint
{ok,T3,_} = erl_scan:string("-type t() :: X..5."), {ok,F3} = erl_parse:parse_form(T3),
{ok,T4,_} = erl_scan:string("-module(m). -type t() :: (1+N)..5."), 
R4 = erl_parse:parse_form(element(2,erl_scan:string("-type t() :: (1+N)..5."))),
io:format("control, parse of (1+N)..5 : ~p~n", [element(1,R4)]),
Forms2 = [{attribute,1,module,m}, {attribute,1,type,{t,{type,1,range,[{op,1,'"'"'+'"'"',{integer,1,1},{var,1,'"'"'N'"'"'}},{integer,1,5}]},[]}}],
io:format("control, lint of non-constant range bound: ~p~n", [erl_lint:module(Forms2)]),
halt().'

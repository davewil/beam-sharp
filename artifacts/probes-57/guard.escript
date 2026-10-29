#!/usr/bin/env escript
%%! -pa var
%% Parse the clause `Sign(n) when n <= -1 -> 1` under each grammar variant: what AST does the GUARD get?
%% (guards read by the same alternatives/1, bs_check.erl:5136; bs_check.erl:5122-5131 apply_guard: unknown => credits nothing)
main(_) ->
  Toks = [{'module',1},{uident,1,'M'},{uident,1,'Sign'},{'(',1},{lident,1,n},{')',1},{'when',1},{lident,1,n},{'<=',1},{'-',1},{integer,1,1},{'->',1},{integer,1,1},{'$end',1}],
  [begin R = P:parse(Toks),
     io:format("~-6s ~p~n",[P, case R of {ok,[_,{function,_,_,_,Cls}|_]} -> Cls; {ok,X}->X; E->E end]) end || P <- [base_p,g1_p,g2_p,g1c_p]].

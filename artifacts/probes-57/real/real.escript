#!/usr/bin/env escript
%%! -pa . -pa ../var
%% REAL bs_check:refine/3 + bs_types (unmodified repo sources, erlc +export_all, OTP 25) on ASTs from the real yecc parsers.
main(_) ->
  Rows = ["value >= -5","value >= -5 and value <= 5","value >= 1 or value <= -1","value <= 3 or value >= 10","value != 0","-5 <= value","value >= - -5","value >= 2 - 7","value >= -x"],
  [ begin
      Cells = [begin
         {ok,[_,{type_refined,_,_,_,Pred}]} = P:parse(tok("module M type T = int where "++S)++[{'$end',1}]),
         try bs_types:to_string(bs_check:refine(bs_types:int(), Pred, 1)) of F -> lists:flatten(io_lib:format("~s",[F]))
         catch error:{opaque_refinement,_} -> "REFUSED"; C:E -> io_lib:format("~p:~p",[C,E]) end
       end || P <- [base_p,g2_p,g1c_p]],
      io:format("~-28s base=~-22s g2=~-22s g1c=~s~n",[S|Cells]) end || S <- Rows].

tok(S) -> [t(W) || W <- string:tokens(re:replace(re:replace(S,"([-*/()])"," & ",[global,{return,list}]),"x"," x ",[global,{return,list}])," ")].
t("-")->{'-',1}; t(">=")->{'>=',1}; t("<=")->{'<=',1}; t("and")->{'and',1}; t("or")->{'or',1}; t("(")->{'(',1}; t(")")->{')',1}; t("=")->{'=',1};
t("!=")->{'!=',1}; t("type")->{'type',1}; t("where")->{'where',1}; t("module")->{'module',1};
t(W=[C|_]) when C>=$0,C=<$9 -> {integer,1,list_to_integer(W)};
t(W=[C|_]) when C>=$A,C=<$Z -> {uident,1,list_to_atom(W)};
t(W) -> {lident,1,list_to_atom(W)}.

#!/usr/bin/env escript
%%! -pa var
%% Hand tokenizer (NOT bs_lexer: its leex output needs OTP 27) feeding the REAL yecc-generated bs_parser.
tok(S) -> [t(W) || W <- string:tokens(re:replace(re:replace(S,"-"," - ",[global,{return,list}]),"([()])"," \\1 ",[global,{return,list}]), " ")].
t("-")->{'-',1}; t(">=")->{'>=',1}; t("<=")->{'<=',1}; t("and")->{'and',1}; t("or")->{'or',1};
t("+")->{'+',1}; t("*")->{'*',1}; t("(")->{'(',1}; t(")")->{')',1}; t("=")->{'=',1};
t("!=")->{'!=',1}; t("<")->{'<',1}; t(">")->{'>',1};
t("type")->{'type',1}; t("where")->{'where',1}; t("module")->{'module',1};
t(W=[C|_]) when C>=$0,C=<$9 -> {integer,1,list_to_integer(W)};
t(W=[C|_]) when C>=$A,C=<$Z -> {uident,1,list_to_atom(W)};
t(W) -> {lident,1,list_to_atom(W)}.
main(A) ->
  Cases = ["value >= -5","value >= -5 and value <= 5","value >= 1 or value <= -1",
    "value >= - -5","value >= 2 - 7","value >= -( 5 )","value >= -x","value <= 3 or value >= 10",
    "value != 0","-5 <= value","value >= 0 - 5","value >= -5 * 2","value >= 3 - -5","value >= -5 + 1","value >= -2147483648", "value >= - 0"],
  [begin
     Toks = tok("module M type T = int where "++C) ++ [{'$end',1}],
     R = (list_to_atom(hd(A)++"_p")):parse(Toks),
     io:format("~-32s ~p~n",[C, case R of {ok,[_,{type_refined,_,_,_,P}]} -> P; {ok,X}->X; E->E end])
   end || C <- Cases].

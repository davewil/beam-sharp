#!/usr/bin/env bash
# parse_shape.sh [EBIN] : what the checker is actually handed for `value >= -5` (the ticket says a `0 - 5` e_op; F51 changed that).
S=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad
EBIN=${1:-$S/bsc-ebin}; source $S/env.sh
erl -noshell -pa $EBIN -eval '
P = fun(Src) -> {ok,T,_} = bs_lexer:string("module M\ntype T = int where " ++ Src ++ "\n"), {ok,[_,{type_refined,_,_,_,Pred}]} = bs_parser:parse(T), Pred end,
[io:format("~-26s ~w~n", [S, P(S)]) || S <- ["value >= -5","value >= - 5","value >= -(5)","value >= -(-5)","value >= 0 - 5","value >= -0xFF","value >= -1.5"]],
%% alternatives/1 is not exported: show the consequence through refine via the public resolve path instead (see corpus.sh)
halt().'

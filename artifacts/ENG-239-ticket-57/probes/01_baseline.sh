#!/bin/bash
# H1: the ticket's table still holds at HEAD on the real parser+checker (OTP 25, lines-only lexer shim).
# H2: the AST is {e_neg,_,{e_int,_,5}}, NOT the ticket's `0 - 5` (F51 changed it after the ticket was written).
# H3: the pattern spelling `<= -1` carries a plain negative integer, no node.
# FALSIFIED if: any row the ticket calls refused is accepted, or the AST has a '-' e_op, or p_rel holds a node.
W=${W:-/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/w57}
D=$(cd "$(dirname "$0")" && pwd)
erlc -o $W/ebin $D/drv.erl $D/guards.erl $D/table.erl
erl -noshell -pa $W/ebin -eval '
io:format("OTP ~s~n",[erlang:system_info(otp_release)]),
S="module M\ntype T = int where value >= -5\npublic int F(T d)\nF(d) -> d\n",
[{type_refined,_,_,_,P}]=drv:shape(S), io:format("refinement AST: ~p~n",[P]),
Pat="module M\npublic atom Sign(int n)\nSign(<= -1) -> :neg\nSign(_) -> :other\n",
D=drv:parse(Pat), io:format("pattern AST:    ~p~n",[[element(4,C) || C <- D, element(1,C) =:= clause, element(3,C) =:= '"'"'Sign'"'"']]),
io:format("pattern program under bs_check: ~p~n",[drv:run(Pat)]),
io:format("--- table ---~n"), table:main(), halt().'

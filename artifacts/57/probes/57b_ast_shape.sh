#!/usr/bin/env bash
# 57b: what does `value >= -5` actually parse to NOW? The ticket says `{e_op,'-',{e_int,0},{e_int,5}}` (0 - 5).
# bs_parser.yrl:589 says unary minus is `e_neg` since F51.
B=${B:-/tmp/bsc57}
erl -noshell -pa $B/ebin -eval '
P = fun(Src) ->
  {ok,T,_} = bs_lexer:string(Src), {ok,A} = bs_parser:parse(T), A end,
Show = fun(Label, Src) -> io:format("~-28s ~s~n  => ~p~n", [Label, string:trim(Src), P(Src)]) end,
Show("refinement  value >= -5", "module M\ntype T = int where value >= -5\n"),
Show("refinement  value >= 0 - 5", "module M\ntype T = int where value >= 0 - 5\n"),
Show("refinement  value >= 5", "module M\ntype T = int where value >= 5\n"),
Show("pattern     F(<= -1)", "module M\npublic int F(int n)\nF(<= -1) -> 1\nF(_) -> 2\n"),
Show("pattern     F(-5)", "module M\npublic int F(int n)\nF(-5) -> 1\nF(_) -> 2\n"),
halt().'

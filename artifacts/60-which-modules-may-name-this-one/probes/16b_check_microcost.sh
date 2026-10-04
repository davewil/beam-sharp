#!/bin/bash
# (d, continued) The whole-process timings in 16 are noise-dominated (range 2.7-5.9 s inside one configuration).
# So bound the check's own work directly: the prototype's predicate, copied verbatim from /tmp/c60a/src/bs_check.erl,
# run 9900 times (= 5 passes x 1980 using lines, the count measured in 16) over dotted atom names.
export PATH=/opt/otp28/bin:$PATH
echo "predicate in the prototype:"; sed -n '/^at_or_under/,/^$/p;/^visible_to/,/^$/p' /tmp/c60a/src/bs_check.erl
erl -noshell -eval '
 AtOrUnder = fun(Self, Prefix) -> S = atom_to_list(Self), P = atom_to_list(Prefix), S =:= P orelse lists:prefix(P ++ ".", S) end,
 Self = list_to_atom("Big.G7.M12"), Prefix = list_to_atom("Big.G7"),
 Loop = fun L(0) -> ok; L(N) -> true = AtOrUnder(Self, Prefix), L(N-1) end,
 {US, ok} = timer:tc(fun() -> Loop(9900) end),
 io:format("9900 predicate evaluations: ~p microseconds total (~p ns each)~n",[US, US*1000 div 9900]),
 {US2, ok} = timer:tc(fun() -> Loop(990000) end),
 io:format("990000 evaluations: ~p microseconds total~n",[US2]),
 halt().'

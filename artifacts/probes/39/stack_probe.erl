%% Strongest counterargument to inlining: what does a crash look like when a callee was inlined?
-module(stack_probe).
-export([run/0, outer/1]).
-compile({nowarn_unused_function, [inner/1]}).
inner(1) -> one;
inner(2) -> two.
outer(X) -> {ok, inner(X)}.
run() -> try outer(3) catch C:R:St -> {C, R, [{F,A,proplists:get_value(line,L)} || {_,F,A,L} <- lists:sublist(St,2)]} end.

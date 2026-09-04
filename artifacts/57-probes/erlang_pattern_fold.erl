-module(erlang_pattern_fold).
-export([f/1, test/0]).

%% Erlang's pattern grammar has NO dedicated negative-literal production --
%% pat_expr -> prefix_op pat_expr is the SAME generic rule expr uses. This
%% probe checks whether Erlang's pattern-compilation constant-folds ARBITRARY
%% closed arithmetic in pattern position (not just unary-minus-over-literal),
%% which is what erl_eval:partial_eval/1 (called from v3_core:pattern/2) would
%% predict, or whether it's special-cased to negation only.
f(-5)   -> neg_five;
f(2 + 3) -> two_plus_three;   % constant-fold in PATTERN position, not just '-'
f(1 bsl 4) -> shift;
f(_)    -> other.

test() ->
    io:format("f(-5)     = ~p~n", [f(-5)]),
    io:format("f(5)      = ~p~n", [f(5)]),   % should hit two_plus_three (2+3=5)
    io:format("f(16)     = ~p~n", [f(16)]),  % should hit shift (1 bsl 4 = 16)
    io:format("f(0)      = ~p~n", [f(0)]),
    halt().

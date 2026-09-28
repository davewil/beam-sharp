-module(i_ex_g).
-export([loop/2]).
loop(0, A) when erlang:is_integer(A) -> A;
loop(N, A) when erlang:is_integer(N) andalso erlang:is_integer(A) -> loop(N - 1, A + N).

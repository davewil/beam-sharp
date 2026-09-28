-module(i_priv_g).
-export([run/2]).
run(N, A) when erlang:is_integer(N) andalso erlang:is_integer(A) -> loop(N, A).
loop(0, A) when erlang:is_integer(A) -> A;
loop(N, A) when erlang:is_integer(N) andalso erlang:is_integer(A) -> loop(N - 1, A + N).

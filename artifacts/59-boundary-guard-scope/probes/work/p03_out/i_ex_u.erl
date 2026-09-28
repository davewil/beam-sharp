-module(i_ex_u).
-export([loop/2]).
loop(0, A) -> A;
loop(N, A) -> loop(N - 1, A + N).

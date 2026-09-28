-module(i_priv_uU).
-export([run/2]).
run(N, A) -> loop(N, A).
loop(0, A) -> A;
loop(N, A) -> loop(N - 1, A + N).

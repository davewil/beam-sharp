-module(trace13).
-export([run/1]).
run(X) -> 1 + boom(X).
boom(X) -> 10 div X.

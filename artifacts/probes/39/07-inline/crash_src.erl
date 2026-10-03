-module(crash_src).
-export([go/1]).
go(X) -> 1 + f(X).
f(1) -> 1.
